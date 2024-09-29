use alloy::{
    node_bindings::Anvil,
    primitives::{U256},
    providers::ProviderBuilder,
    sol,
};

use eyre::Result;

mod rest;

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

#[tokio::main]
async fn main() -> Result<()> {

    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .on_anvil_with_wallet();

    let contract = BlazingContract::deploy(provider.clone()).await?;

    // TESTING SETUP
    let anvil = Anvil::new().try_spawn()?;
    let alice = anvil.addresses()[0];
    let bob = anvil.addresses()[1];
    let charlie = anvil.addresses()[2];
    println!("alice: {}", alice);
    println!("bob: {}", bob);
    println!("charlie: {}", charlie);

    // Deploy ERC20 contracts for testing
    let token_a_contract = ERC20Example::deploy(provider.clone()).await?;
    let token_b_contract = ERC20Example::deploy(provider.clone()).await?;
    let token_c_contract = ERC20Example::deploy(provider.clone()).await?;

    // Give some tokens to Bob
    let amount = U256::from(50000000000u64);

    token_a_contract
        .transfer(bob, amount)
        .send()
        .await?
        .watch()
        .await?;

    token_b_contract
        .transfer(bob, amount)
        .send()
        .await?
        .watch()
        .await?;

    token_c_contract
        .transfer(bob, amount)
        .send()
        .await?
        .watch()
        .await?;


        token_a_contract
        .transfer(charlie, amount)
        .send()
        .await?
        .watch()
        .await?;

    token_b_contract
        .transfer(charlie, amount)
        .send()
        .await?
        .watch()
        .await?;

    token_c_contract
        .transfer(charlie, amount)
        .send()
        .await?
        .watch()
        .await?;


    let routes = rest::api(provider.clone(), contract.address().clone());
    println!("Start server");
    warp::serve(routes).run(([127, 0, 0, 1], 3030)).await;

    Ok(())
}
