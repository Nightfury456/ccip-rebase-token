// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Aditya Kiran Choudhary
 * @notice This is a cross-chain token that incentivises users to deposit into a vault and gain interests in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate. i.e. the global interest at the time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateIncreaseNotAllowed(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event NewInterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function greantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice set the interest rate in the contract.
     * @param _newInterestRate The new interest rate to be set.
     * @dev The interest rate can only be decreased. If the new interest rate is greater than the old interest rate, revert the transaction.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Set the Interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateIncreaseNotAllowed(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit NewInterestRateSet(_newInterestRate);
    }

    /**
     * @notice get the principle balance of the user (minted by the user) not including any interest that has accured since the last time the user interacted with the protocol.
     * @param _user The address of the user.
     * @return The principle balance of the user.
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice mint tokens to the user when they deposit into the vault.
     * @param _to The address of the user to whom the tokens are to be minted.
     * @param _amount The amount of tokens to be minted.
     * @dev This function will mint the tokens to the user and set the interest rate for the user.
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice burn tokens from the user when they withdraw from the vault.
     * @param _from The address of the user from whom the tokens are to be burned.
     * @param _amount The amount of tokens to be burned.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice calculate the balance for the user including the interest that has accumulated since the last update.
     * (principle balance) + some interest that has accured.
     * @param _user The address of the user.
     * @return The balance of the user including the interest that has accumulated since the last update.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of tokens that have actually minted to the user).
        // multiply the principle balance by the interest that has accumulated in the time since the balance is last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice transfer tokens from the user to another user.
     * @param _recipient The address of the user to whom the tokens are to be transferred.
     * @param _amount The amount of tokens to be transferred.
     * @return true if the transfer was successful, false otherwise.
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice transfer tokens from one user to another user.
     * @param _sender The address of the user from whom the tokens are to be transferred.
     * @param _recipient The address of the user to whom the tokens are to be transferred.
     * @param _amount The amount of tokens to be transferred.
     * @return true if the transfer was successful, false otherwise.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice calculate the interest that has accumulated since the last update.
     * @param _user The address of the user.
     * @return linearInterest The interest that has accumulated since the last update.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // (principle_amount) + (principle_amount * user_interest_rate * time_elapsed)
        // principle_amount(1 + (user_interest_rate * time_elapsed))
        // deposit: 10 tokens
        // interest rate: 0.5 tokens per second
        // time elapsed: 2 seconds
        // 10 + (10 * 0.5 * 2) = 10 + 10 = 20 tokens
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice mint the accrued interest to the user since the last time they interected to the protocol(ex: burn, mint, transfer).
     * @param _user The user to mint the accured inteerst to.
     * @dev This function will mint the accrued interest to the user.
     */
    function _mintAccruedInterest(address _user) internal {
        // 1. find current balance of rebase tokens that have been minted to the user -> currentBalance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // 2. calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // 3. calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // set the user last updated timestamp.
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint to mint tokens to the user.
        _mint(_user, balanceIncrease);
    }

    /////////////// GETTERS ///////////////

    /**
     * @notice get the interest rate that i scorrently set for the contract.
     * @return The interest rate of the contract.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice get the interest rate from the user.
     * @param _user The address of the user.
     * @return The interest rate of the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
