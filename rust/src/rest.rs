use alloy::{
    network::Ethereum,
    network::{EthereumWallet, TransactionBuilder},
    primitives::{Address, U256},
    providers::{
        fillers::{
            BlobGasFiller, ChainIdFiller, FillProvider, GasFiller, JoinFill, NonceFiller,
            WalletFiller,
        },
        layers::AnvilProvider,
        Identity, Provider, RootProvider,
    },
    rpc::types::TransactionRequest,
    sol,
    transports::http::{Client, Http},
};
use eyre::Result;
use serde::{Deserialize, Serialize};
use warp::{reject::Reject, reply::Json, Filter};

#[derive(Debug)]
struct InsufficientBalanceError;

#[derive(Debug)]
struct TransactionError;

impl Reject for InsufficientBalanceError {}
impl Reject for TransactionError {}

#[derive(Deserialize, Serialize)]
struct CollectInput {
    recipient: Address,
    senders: Vec<Address>,
    amounts: Vec<Vec<U256>>,
    tokens: Vec<Address>,
    is_percentage: bool,
}

#[derive(Deserialize, Serialize)]
struct DisperseInput {
    sender: Address,
    recipients: Vec<Address>,
    amounts: Vec<Vec<U256>>,
    tokens: Vec<Address>,
    is_percentage: bool,
}

sol!(
    #[sol(rpc)]
    BlazingContract,
    "../foundry/out/BlazingContract.sol/BlazingContract.json"
);

sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    ERC20Example,
    "./artifacts/ERC20Example.json"
);

type MyProvider = FillProvider<
    JoinFill<
        JoinFill<
            Identity,
            JoinFill<GasFiller, JoinFill<BlobGasFiller, JoinFill<NonceFiller, ChainIdFiller>>>,
        >,
        WalletFiller<EthereumWallet>,
    >,
    AnvilProvider<RootProvider<Http<Client>>, Http<Client>>,
    Http<Client>,
    Ethereum,
>;

pub fn api(
    provider: MyProvider,
    blazing_contract_address: Address,
) -> impl Filter<Extract = impl warp::Reply, Error = warp::Rejection> + Clone {
    let collect_provider = provider.clone();
    let collect_address = blazing_contract_address;
    let collect = warp::path("collect")
        .and(warp::post())
        .and(warp::body::json())
        .and_then(move |data| collect(data, collect_address, collect_provider.clone()));

    let disperse_provider = provider.clone();
    let disperse_address = blazing_contract_address;
    let disperse = warp::path("disperse")
        .and(warp::post())
        .and(warp::body::json())
        .and_then(move |data| disperse(data, disperse_address, disperse_provider.clone()));

    collect.or(disperse)
}

async fn collect(
    mut data: CollectInput,
    blazing_contract_address: Address,
    provider: MyProvider,
) -> Result<Json, warp::Rejection> {
    let contract = BlazingContract::new(blazing_contract_address, provider.clone());

    // Check allowances and balances for all tokens
    for (token_index, &token_address) in data
        .tokens
        .iter()
        .enumerate()
        .filter(|(_, &addr)| addr != Address::ZERO)
    {
        let erc20_contract = ERC20Example::new(token_address, provider.clone());
        for (sender_index, &sender) in data.senders.iter().enumerate() {
            // Check balance
            let balance = erc20_contract
                .balanceOf(sender)
                .call()
                .await
                .map_err(|e| {
                    eprintln!("Failed to get balance: {}", e);
                    warp::reject::custom(TransactionError)
                })?
                ._0;

            // Check allowance
            let allowance = erc20_contract
                .allowance(sender, blazing_contract_address)
                .call()
                .await
                .map_err(|e| {
                    eprintln!("Failed to get allowance: {}", e);
                    warp::reject::custom(TransactionError)
                })?
                ._0;

            // Calculate actual amount, and replace the % value with the actual amount
            let amount = calculate_amount(data.is_percentage, balance, data.amounts[token_index][sender_index])?;
            data.amounts[token_index][sender_index] = amount;

            if balance < amount {
                return Err(warp::reject::custom(InsufficientBalanceError));
            }
            if allowance < amount {
                // TODO: Maybe give error instead of approving?
                erc20_contract
                    .approve(*contract.address(), amount)
                    .from(sender)
                    .send()
                    .await
                    .map_err(|e| {
                        eprintln!("Failed to send approve transaction: {}", e);
                        warp::reject::custom(TransactionError)
                    })?
                    .watch()
                    .await
                    .map_err(|e| {
                        eprintln!("Failed to watch approve transaction: {}", e);
                        warp::reject::custom(TransactionError)
                    })?;
            }
        }
    }

    // Transfer ETH to contract for each sender if needed
    if let Some(eth_index) = data.tokens.iter().position(|&token| token == Address::ZERO) {
        for (sender_index, &sender) in data.senders.iter().enumerate() {
            let eth_balance = provider.get_balance(sender).await.map_err(|e| {
                eprintln!("Failed to get ETH balance: {}", e);
                warp::reject::custom(TransactionError)
            })?;

            // Calculate actual amount, and replace the % value with the actual amount
            let amount = calculate_amount(data.is_percentage, eth_balance, data.amounts[eth_index][sender_index])?;
            data.amounts[eth_index][sender_index] = amount;

            // Skip zero amounts, which can happen if not all senders are sending ETH
            if !amount.is_zero() {
                let tx = TransactionRequest::default()
                    .with_from(sender)
                    .with_to(*contract.address())
                    .with_value(amount);
                let _tx_hash = provider
                    .send_transaction(tx)
                    .await
                    .map_err(|e| {
                        eprintln!("Failed to send transaction: {}", e);
                        warp::reject::custom(TransactionError)
                    })?
                    .watch()
                    .await
                    .map_err(|e| {
                        eprintln!("Failed to watch transaction: {}", e);
                        warp::reject::custom(TransactionError)
                    })?;
            }
        }
    }

    let builder = contract.collect(data.recipient, data.senders, data.amounts, data.tokens);
    let tx_hash = builder
        .send()
        .await
        .map_err(|e| {
            eprintln!("Failed to send transaction: {}", e);
            warp::reject::custom(TransactionError)
        })?
        .watch()
        .await
        .map_err(|e| {
            eprintln!("Failed to watch transaction: {}", e);
            warp::reject::custom(TransactionError)
        })?;

    Ok(warp::reply::json(&tx_hash))
}

async fn disperse(
    mut data: DisperseInput,
    blazing_contract_address: Address,
    provider: MyProvider,
) -> Result<Json, warp::Rejection> {
    let contract = BlazingContract::new(blazing_contract_address, provider.clone());

    // Handle ERC20 tokens
    for (token_index, &token_address) in data
        .tokens
        .iter()
        .enumerate()
        .filter(|(_, &addr)| addr != Address::ZERO)
    {
        let erc20_contract = ERC20Example::new(token_address, provider.clone());
        let balance = erc20_contract
            .balanceOf(data.sender)
            .call()
            .await
            .map_err(|e| {
                eprintln!("Failed to get balance: {}", e);
                warp::reject::custom(TransactionError)
            })?
            ._0;
        let allowance = erc20_contract
            .allowance(data.sender, *contract.address())
            .call()
            .await
            .map_err(|e| {
                eprintln!("Failed to get allowance: {}", e);
                warp::reject::custom(TransactionError)
            })?
            ._0;

        let actual_amounts = data.amounts[token_index]
            .iter()
            .map(|&amount| calculate_amount(data.is_percentage, balance, amount))
            .collect::<Result<Vec<U256>, _>>()?;

        if data.is_percentage {
            data.amounts[token_index] = actual_amounts.clone();
        }

        let total_amount: U256 = actual_amounts.iter().sum();

        if balance < total_amount {
            return Err(warp::reject::custom(InsufficientBalanceError));
        }
        if allowance < total_amount {
            // TODO: Maybe give error instead of approving?
            erc20_contract
                .approve(*contract.address(), total_amount)
                .from(data.sender)
                .send()
                .await
                .map_err(|e| {
                    eprintln!("Failed to send approve transaction: {}", e);
                    warp::reject::custom(TransactionError)
                })?
                .watch()
                .await
                .map_err(|e| {
                    eprintln!("Failed to watch approve transaction: {}", e);
                    warp::reject::custom(TransactionError)
                })?;
        }
    }

    // Handle ETH
    if let Some(eth_index) = data.tokens.iter().position(|&token| token == Address::ZERO) {
        let eth_balance = provider.get_balance(data.sender).await.map_err(|e| {
            eprintln!("Failed to get ETH balance: {}", e);
            warp::reject::custom(TransactionError)
        })?;
        let actual_amounts = data.amounts[eth_index]
            .iter()
            .map(|&amount| calculate_amount(data.is_percentage, eth_balance, amount))
            .collect::<Result<Vec<U256>, _>>()?;

        if data.is_percentage {
            data.amounts[eth_index] = actual_amounts.clone();
        }

        let total_eth_amount: U256 = actual_amounts.iter().sum();
        if !total_eth_amount.is_zero() {
            let tx = TransactionRequest::default()
                .with_from(data.sender)
                .with_to(*contract.address())
                .with_value(total_eth_amount);
            let _tx_hash = provider
                .send_transaction(tx)
                .await
                .map_err(|e| {
                    eprintln!("Failed to send ETH transaction: {}", e);
                    warp::reject::custom(TransactionError)
                })?
                .watch()
                .await
                .map_err(|e| {
                    eprintln!("Failed to watch ETH transaction: {}", e);
                    warp::reject::custom(TransactionError)
                })?;
        }
    }

    let tx_hash = contract
        .disperse(data.sender, data.recipients, data.amounts, data.tokens)
        .send()
        .await
        .map_err(|e| {
            eprintln!("Failed to send disperse transaction: {}", e);
            warp::reject::custom(TransactionError)
        })?
        .watch()
        .await
        .map_err(|e| {
            eprintln!("Failed to watch disperse transaction: {}", e);
            warp::reject::custom(TransactionError)
        })?;

    Ok(warp::reply::json(&tx_hash))
}

fn calculate_amount(
    is_percentage: bool,
    balance: U256,
    input_amounts: U256,
) -> Result<U256, warp::Rejection> {
    if is_percentage {
        balance
            .checked_mul(input_amounts)
            .and_then(|v| v.checked_div(U256::from(100)))
            .ok_or_else(|| {
                eprintln!("Overflow in percentage calculation");
                warp::reject::custom(TransactionError)
            })
    } else {
        Ok(input_amounts)
    }
}