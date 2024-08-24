// SPDX-License-Identifier: NO License

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IYidocyToken.sol";
import "./IRewardPool.sol";

contract RewardTreasury {
    IYidocyToken internal immutable _stakingToken;
    IERC20 internal immutable _rewardToken;
    address internal immutable _pool;

    mapping(uint256=>uint256) internal _rewardAmountHistory;
    uint256 internal _phase;

    constructor(address stakingToken, address rewardToken, address rewardPool) {
        require(stakingToken != address(0), "RewardTreasury : Cannot set the stakingToken to zero address");
        require(rewardToken != address(0), "RewardTreasury : Cannot set the rewardToken to zero address");
        require(rewardPool != address(0), "RewardTreasury : Cannot set the rewardPool to zero address");
        _stakingToken = IYidocyToken(stakingToken);
        _rewardToken = IERC20(rewardToken);
        _pool = rewardPool;
    }

    modifier onlyAdmin() {        
        require(_stakingToken.isAdmin(msg.sender), "RewardTreasury : Restricted to admins.");
        _;
    }

    // function transferRewardToken(uint256 amount) external onlyAdmin {
    //     if (amount > 0) {
    //         require(_rewardToken.transfer(_pool, amount));
    //     }
    //     _rewardAmountHistory[_phase] = amount;
    //     _phase ++;
    // }

    function getRewardAmountHistory(uint256 phase) external view returns(uint256) {
        return _rewardAmountHistory[phase];
    }
}
