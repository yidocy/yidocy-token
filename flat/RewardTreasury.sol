// SPDX-License-Identifier: NO LICENCE

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IYidocyToken is IERC20 {
    function isAdmin(address account) external view returns (bool);
    function adminRoleMembersCount() external view returns (uint256);
    function getAdminRoleMembers() external view returns (address[] memory adminRoleMembers);
}

interface IRewardPool {
    function notifyReward(uint256 amount) external;
    function getUserStakingBalance(address account) external view returns(uint256);
    function deposit(address staker, uint256 amount) external;
}

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
