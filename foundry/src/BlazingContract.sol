// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IERC20.sol";

/// @title A contract to collect and disperse ETH and ERC20 tokens
/// @author arjanjohan
/// @notice If you are using this contract for ETH, send ETH to the contract address seperately.
contract BlazingContract {
    /// @notice Function to receive ETH
    receive() external payable {}

    /// @notice Function to disperse ETH and ERC20 tokens to multiple recipients
    /// @param sender The address of the sender
    /// @param recipients The addresses of the recipients
    /// @param amounts The amounts to disperse stored as [token][recipient]
    /// @param tokens The addresses of the tokens to disperse
    function disperse(
        address sender,
        address[] calldata recipients,
        uint256[][] calldata amounts,
        address[] calldata tokens
    ) public {
        require(tokens.length == amounts.length, "Mismatched arrays");
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 totalAmount = 0;
            for (uint256 j = 0; j < recipients.length; j++) {
                totalAmount += amounts[i][j];
            }
            if (tokens[i] == address(0)) {
                // ETH transfer
                require(
                    address(this).balance >= totalAmount,
                    "Insufficient ETH balance"
                );
                for (uint256 j = 0; j < recipients.length; j++) {
                    (bool sent, ) = recipients[j].call{value: amounts[i][j]}("");
                    require(sent, "Failed to send Ether");
                }
            } else {
                // ERC20 transfers
                IERC20 token = IERC20(tokens[i]);
                require(
                    token.allowance(sender, address(this)) >= totalAmount,
                    "Insufficient allowance"
                );
                require(
                    token.balanceOf(sender) >= totalAmount,
                    "Insufficient token balance"
                );

                for (uint256 j = 0; j < recipients.length; j++) {
                    require(
                        token.transferFrom(
                            sender,
                            recipients[j],
                            amounts[i][j]
                        ),
                        "Failed to send token"
                    );
                }
            }
        }
    }

    /// @notice Function to collect ETH and ERC20 tokens from multiple senders
    /// @param recipient The address of the recipient
    /// @param senders The addresses of the senders
    /// @param amounts The amounts to collect stored as [token][sender]
    /// @param tokens The addresses of the tokens to collect
    function collect(
        address recipient,
        address[] calldata senders,
        uint256[][] calldata amounts, // [token][sender]
        address[] calldata tokens
    ) public {
        require(tokens.length == amounts.length, "Mismatched arrays");
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                // ETH transfer
                uint256 totalAmount = 0;
                for (uint256 j = 0; j < senders.length; j++) {
                    totalAmount += amounts[i][j];
                }
                require(
                    address(this).balance >= totalAmount,
                    "Insufficient ETH balance"
                );
                (bool sent, ) = recipient.call{value: totalAmount}("");
                require(sent, "Failed to send Ether");
            } else {
                // ERC20 transfers
                IERC20 token = IERC20(tokens[i]);

                for (uint256 j = 0; j < senders.length; j++) {
                    require(
                        token.allowance(senders[j], address(this)) >=
                            amounts[i][j],
                        "Insufficient allowance"
                    );
                    require(
                        token.balanceOf(senders[j]) >= amounts[i][j],
                        "Insufficient token balance"
                    );

                    require(
                        token.transferFrom(
                            senders[j],
                            recipient,
                            amounts[i][j]
                        ),
                        "Failed to send token"
                    );
                }
            }
        }
    }
}
