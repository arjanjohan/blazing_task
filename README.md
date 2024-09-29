## Task
Develop an application on Rust that allow to do this:

Disperse:
Being able to send ETH to multiples wallets at the same time using an smart contract BUT ALSO any ERC20 tokens. I can also select % instead of amount.

Collect:
Being able to collect ETH from multiples at the same time and send just to one wallet using an smart contrct but ALSO ERC20 tokens using % of the wallet.

Application needs to have an API where you can send your body and it will process it and return tx hash. Develop the smart contract using solidity under Foundry framework. Optimize it for gas as much as you can.

## Solution

### Getting started
First compile the Solidity contract
```
cd foundry
forge build
cd ..
```
Then start the API 

```
cd rust
cargo watch -q -c -w src/ -x run
```
Now you can query the API using the example requests in [dev.http](dev.http).

### Overview

Here is a brief description of the files used in my solution:

### [BlazingContract](foundry/src/BlazingContract.sol)
Smart contract with the logic is collect and distribute ERC20 and ETH.

### [BlazingContract.t.sol](foundry/test/BlazingContract.t.sol)
Tests for BlazingContract.sol includes these test cases:
```
Ran 5 tests for test/BlazingContract.t.sol:blazingContractTest
[PASS] testCollectAmountsErc20() (gas: 472523)
[PASS] testCollectAmountsEth() (gas: 53125)
[PASS] testDisperseAmountsErc20() (gas: 272067)
[PASS] testDisperseAmountsErc20Eth() (gas: 345733)
[PASS] testDisperseAmountsEth() (gas: 89465)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 1.85ms (3.62ms CPU time)
```

### [main.rs](rust/src/main.rs)
Used to initialize BlazingContract and ERC20 contracts, fund some accounts for testing and start the API server.

### [rest.rs](rust/src/rest.rs)
API in Rust to execute the collect and disperse functions.

### [dev.http](dev.http)
File to test the API