// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BlazingContract} from "../src/BlazingContract.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract blazingContractTest is Test {
    BlazingContract public blazingContract;
    MockERC20 token1;
    MockERC20 token2;
    MockERC20 token3;
    address owner;
    address addr1;
    address addr2;
    address _addr3;

    function setUp() public {
        owner = address(this);
        addr1 = address(0x1);
        addr2 = address(0x2);
        _addr3 = address(0x3); // unused

        token1 = new MockERC20("Mock Token 1", "MTK1", 1000 ether);
        token2 = new MockERC20("Mock Token 2", "MTK2", 1000 ether);
        token3 = new MockERC20("Mock Token 3", "MTK3", 1000 ether);
        blazingContract = new BlazingContract();

        token1.approve(address(blazingContract), 1000 ether);
        token2.approve(address(blazingContract), 1000 ether);
        token3.approve(address(blazingContract), 1000 ether);
    }

    function testDisperseAmountsErc20() public {
        address[] memory recipients = new address[](2);
        recipients[0] = addr1;
        recipients[1] = addr2;

        uint256[][] memory amounts = new uint256[][](3);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10 ether;
        amounts[0][1] = 20 ether;

        amounts[1] = new uint256[](2);
        amounts[1][0] = 30 ether;
        amounts[1][1] = 40 ether;

        amounts[2] = new uint256[](2);
        amounts[2][0] = 50 ether;
        amounts[2][1] = 60 ether;

        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);
        // Store initial balances
        uint256[] memory initialBalances = new uint256[](6);
        initialBalances[0] = token1.balanceOf(addr1);
        initialBalances[1] = token1.balanceOf(addr2);
        initialBalances[2] = token2.balanceOf(addr1);
        initialBalances[3] = token2.balanceOf(addr2);
        initialBalances[4] = token3.balanceOf(addr1);
        initialBalances[5] = token3.balanceOf(addr2);

        blazingContract.disperse(owner, recipients, amounts, tokens);

        // Check final balances
        assertEq(
            token1.balanceOf(addr1),
            initialBalances[0] + 10 ether,
            "Incorrect token1 balance for addr1"
        );
        assertEq(
            token1.balanceOf(addr2),
            initialBalances[1] + 20 ether,
            "Incorrect token1 balance for addr2"
        );
        assertEq(
            token2.balanceOf(addr1),
            initialBalances[2] + 30 ether,
            "Incorrect token2 balance for addr1"
        );
        assertEq(
            token2.balanceOf(addr2),
            initialBalances[3] + 40 ether,
            "Incorrect token2 balance for addr2"
        );
        assertEq(
            token3.balanceOf(addr1),
            initialBalances[4] + 50 ether,
            "Incorrect token3 balance for addr1"
        );
        assertEq(
            token3.balanceOf(addr2),
            initialBalances[5] + 60 ether,
            "Incorrect token3 balance for addr2"
        );
    }

    function testDisperseAmountsEth() public {
        address[] memory recipients = new address[](2);
        recipients[0] = addr1;
        recipients[1] = addr2;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 1 ether;
        amounts[0][1] = 1 ether;

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);

        // Check initial balances
        uint256 initialBalance1 = addr1.balance;
        uint256 initialBalance2 = addr2.balance;

        // The ETH transfer in is not handles by contract, so we simulate it
        vm.deal(address(blazingContract), 2 ether);
        assertEq(
            address(blazingContract).balance,
            2 ether,
            "Incorrect ETH balance for contract"
        );

        blazingContract.disperse(owner, recipients, amounts, tokens);

        // Check if the contract has no ETH balance left
        assertEq(
            address(blazingContract).balance,
            0 ether,
            "Incorrect ETH balance for contract"
        );

        // Check final balances
        assertEq(
            addr1.balance,
            initialBalance1 + 1 ether,
            "Incorrect ETH balance for addr1"
        );
        assertEq(
            addr2.balance,
            initialBalance2 + 1 ether,
            "Incorrect ETH balance for addr2"
        );
    }

    function testDisperseAmountsErc20Eth() public {
        address[] memory recipients = new address[](2);
        recipients[0] = addr1;
        recipients[1] = addr2;

        uint256[][] memory amounts = new uint256[][](4);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10 ether;
        amounts[0][1] = 20 ether;

        amounts[1] = new uint256[](2);
        amounts[1][0] = 30 ether;
        amounts[1][1] = 40 ether;

        amounts[2] = new uint256[](2);
        amounts[2][0] = 50 ether;
        amounts[2][1] = 60 ether;

        amounts[3] = new uint256[](2);
        amounts[3][0] = 1 ether;
        amounts[3][1] = 1 ether;

        address[] memory tokens = new address[](4);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);
        tokens[3] = address(0);

        // Check initial balances
        uint256[] memory initialBalances = new uint256[](8);
        initialBalances[0] = token1.balanceOf(addr1);
        initialBalances[1] = token1.balanceOf(addr2);
        initialBalances[2] = token2.balanceOf(addr1);
        initialBalances[3] = token2.balanceOf(addr2);
        initialBalances[4] = token3.balanceOf(addr1);
        initialBalances[5] = token3.balanceOf(addr2);
        initialBalances[6] = addr1.balance;
        initialBalances[7] = addr2.balance;

        // The ETH transfer in is not handles by contract, so we simulate it
        vm.deal(address(blazingContract), 2 ether);
        assertEq(
            address(blazingContract).balance,
            2 ether,
            "Incorrect ETH balance for contract"
        );

        blazingContract.disperse(owner, recipients, amounts, tokens);

        // Check if the contract has no ETH balance left
        assertEq(
            address(blazingContract).balance,
            0 ether,
            "Incorrect ETH balance for contract"
        );

        // Check final balances
        assertEq(
            token1.balanceOf(addr1),
            initialBalances[0] + 10 ether,
            "Incorrect token1 balance for addr1"
        );
        assertEq(
            token1.balanceOf(addr2),
            initialBalances[1] + 20 ether,
            "Incorrect token1 balance for addr2"
        );
        assertEq(
            token2.balanceOf(addr1),
            initialBalances[2] + 30 ether,
            "Incorrect token2 balance for addr1"
        );
        assertEq(
            token2.balanceOf(addr2),
            initialBalances[3] + 40 ether,
            "Incorrect token2 balance for addr2"
        );
        assertEq(
            token3.balanceOf(addr1),
            initialBalances[4] + 50 ether,
            "Incorrect token3 balance for addr1"
        );
        assertEq(
            token3.balanceOf(addr2),
            initialBalances[5] + 60 ether,
            "Incorrect token3 balance for addr2"
        );
        assertEq(
            addr1.balance,
            initialBalances[6] + 1 ether,
            "Incorrect ETH balance for addr1"
        );
        assertEq(
            addr2.balance,
            initialBalances[7] + 1 ether,
            "Incorrect ETH balance for addr2"
        );
    }

    function testCollectAmountsErc20() public {
        token1.transfer(addr1, 100 ether);
        token1.transfer(addr2, 100 ether);
        token2.transfer(addr1, 100 ether);
        token2.transfer(addr2, 100 ether);
        token3.transfer(addr1, 100 ether);
        token3.transfer(addr2, 100 ether);

        assertEq(token1.balanceOf(addr1), 100 ether);
        assertEq(token1.balanceOf(addr2), 100 ether);
        assertEq(token2.balanceOf(addr1), 100 ether);
        assertEq(token2.balanceOf(addr2), 100 ether);
        assertEq(token3.balanceOf(addr1), 100 ether);
        assertEq(token3.balanceOf(addr2), 100 ether);

        vm.startPrank(addr1);
        token1.approve(address(blazingContract), 100 ether);
        token2.approve(address(blazingContract), 100 ether);
        token3.approve(address(blazingContract), 100 ether);
        vm.stopPrank();

        vm.startPrank(addr2);
        token1.approve(address(blazingContract), 100 ether);
        token2.approve(address(blazingContract), 100 ether);
        token3.approve(address(blazingContract), 100 ether);
        vm.stopPrank();

        address[] memory senders = new address[](2);
        senders[0] = addr1;
        senders[1] = addr2;

        uint256[][] memory amounts = new uint256[][](3);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 10 ether;
        amounts[0][1] = 20 ether;

        amounts[1] = new uint256[](2);
        amounts[1][0] = 30 ether;
        amounts[1][1] = 40 ether;

        amounts[2] = new uint256[](2);
        amounts[2][0] = 50 ether;
        amounts[2][1] = 60 ether;

        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);

        // Check balances before collection
        uint256 ownerToken1Before = token1.balanceOf(owner);
        uint256 addr1Token1Before = token1.balanceOf(addr1);
        uint256 addr2Token1Before = token1.balanceOf(addr2);

        uint256 ownerToken2Before = token2.balanceOf(owner);
        uint256 addr1Token2Before = token2.balanceOf(addr1);
        uint256 addr2Token2Before = token2.balanceOf(addr2);

        uint256 ownerToken3Before = token3.balanceOf(owner);
        uint256 addr1Token3Before = token3.balanceOf(addr1);
        uint256 addr2Token3Before = token3.balanceOf(addr2);

        blazingContract.collect(owner, senders, amounts, tokens);

        // Check balance differences after collection
        assertEq(
            token1.balanceOf(owner) - ownerToken1Before,
            30 ether,
            "Incorrect token1 balance for owner"
        );
        assertEq(
            addr1Token1Before - token1.balanceOf(addr1),
            10 ether,
            "Incorrect token1 balance for addr1"
        );
        assertEq(
            addr2Token1Before - token1.balanceOf(addr2),
            20 ether,
            "Incorrect token1 balance for addr2"
        );

        assertEq(
            token2.balanceOf(owner) - ownerToken2Before,
            70 ether,
            "Incorrect token2 balance for owner"
        );
        assertEq(
            addr1Token2Before - token2.balanceOf(addr1),
            30 ether,
            "Incorrect token2 balance for addr1"
        );
        assertEq(
            addr2Token2Before - token2.balanceOf(addr2),
            40 ether,
            "Incorrect token2 balance for addr2"
        );

        assertEq(
            token3.balanceOf(owner) - ownerToken3Before,
            110 ether,
            "Incorrect token3 balance for owner"
        );
        assertEq(
            addr1Token3Before - token3.balanceOf(addr1),
            50 ether,
            "Incorrect token3 balance for addr1"
        );
        assertEq(
            addr2Token3Before - token3.balanceOf(addr2),
            60 ether,
            "Incorrect token3 balance for addr2"
        );
    }

    function testCollectAmountsEth() public {
        address recipient = 0x199d51a2Be04C65f325908911430E6FF79a15ce3;
        address[] memory senders = new address[](2);
        senders[0] = addr1;
        senders[1] = addr2;

        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](2);
        amounts[0][0] = 1 ether;
        amounts[0][1] = 1 ether;

        address[] memory tokens = new address[](1);
        tokens[0] = address(0);

        // The ETH transfer in is not handles by contract, so we simulate it
        vm.deal(address(blazingContract), 2 ether);
        assertEq(
            address(blazingContract).balance,
            2 ether,
            "Incorrect ETH balance for contract"
        );
        assertEq(
            address(recipient).balance,
            0 ether,
            "Incorrect ETH balance for recipient"
        );

        blazingContract.collect(recipient, senders, amounts, tokens);

        // Check if the contract has no ETH balance left
        assertEq(
            address(blazingContract).balance,
            0 ether,
            "Incorrect ETH balance for contract"
        );
        assertEq(
            address(recipient).balance,
            2 ether,
            "Incorrect ETH balance for recipient"
        );
    }
}
