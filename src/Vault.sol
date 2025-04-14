// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // we need to pass the token address to the contract
    // create a deposit function that mints tokens to the user equal to the amount of the ETH the user deposited
    // create a redeem function that burns the tokens and sends the ETH back to the user
    // create a way to add rewards to the vault

    error Vault__RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Deposit ETH into the vault and mint Rebase tokens in return.
     */
    function deposit() external payable {
        // 1. we need to use the amount of ETH the user deposited to mint the tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @notice Redeem Rebase tokens for ETH.
     * @param _amount The amount of tokens to be redeemed.
     */
    function redeem(uint256 _amount) external {
        // 1. we need to burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. we need to send the ETH back to the user
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    ////// Getters //////

    /**
     * @notice Get the address of the Rebase token contract.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
