// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
 * @title RebaseToken
 * @author Aditya Kiran Choudhary
 * @notice This is a cross-chain token that incentivises users to deposit into a vault and gain interests in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate. i.e. the global interest at the time of depositing.
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateIncreaseNotAllowed(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event NewInterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /*
     * @notice set the interest rate in the contract.
     * @param _newInterestRate The new interest rate to be set.
     * @dev The interest rate can only be decreased. If the new interest rate is greater than the old interest rate, revert the transaction.
     */
    function setInterestRate(uint256 _newInterestRate) external {
        // Set the Interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateIncreaseNotAllowed(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit NewInterestRateSet(_newInterestRate);
    }
    /*
     * @notice mint tokens to the user when they deposit into the vault.
     * @param _to The address of the user to whom the tokens are to be minted.
     * @param _amount The amount of tokens to be minted.
     * @dev This function will mint the tokens to the user and set the interest rate for the user.
     */

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /*
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
    /*
     * @notice calculate the interest that has accumulated since the last update.
     * @param _user The address of the user.
     * @return The interest that has accumulated since the last update.
     */

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amoun tof linear growth
        // (principle_amount) + (principle_amount * user_interest_rate * time_elapsed)
        // principle_amount(1 + (user_interest_rate * time_elapsed))
        // deposit: 10 tokens
        // interest rate: 0.5 tokens per second
        // time elapsed: 2 seconds
        // 10 + (10 * 0.5 * 2) = 10 + 10 = 20 tokens
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccruedInterest(address _user) internal {
        // 1. find current balance of rebase tokens that have been minted to tthe user -> currentBalance
        // 2. calculate their current balance including any interest -> balanceOf
        // 3. calculate the number of tokens that need to be minted to the user -> (2) - (1)
        // call _mint to mint tokens to the user
        // set the user last updated timestamp.
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /*
     * @notice get the interest rate from the user.
     * @param _user The address of the user.
     * @return The interest rate of the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
