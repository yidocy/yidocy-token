// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRewardPool {
    function notifyReward(uint256 amount) external;
    function getUserStakingBalance(address account) external view returns(uint256);
    function deposit(address staker, uint256 amount) external;
}
