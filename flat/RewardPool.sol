// SPDX-License-Identifier: NO License

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
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


contract RewardPool is IRewardPool, ReentrancyGuard {
    IYidocyToken internal immutable _stakingToken;
    IERC20 internal immutable _rewardToken;

    struct ValidSupply {
      uint256 phase;
      uint256 amount;
    }
    struct RewardDist {
      uint256 phase;
      uint256 rewardTime;
      uint256 amount;
      uint256 validSupply;
    }
    struct UserRewardDist {
      uint256 amount;
      uint256 validSupply;
    }
     struct UserInfo {
        uint256 stakingBalance;
        uint256 rewardedAmount;
        ValidSupply[] validSupplies;
        bool exist;
    }

    uint256 internal _totalSupply;
    ValidSupply[] internal _validSupplies;
    RewardDist[] internal _rewardDists;

    uint256 internal _lastRewardTime; // Timestamp in seconds since the epoch
    uint32 internal immutable _rewardDurationInMinute = 24*60; // In Prodution 24 Hours
    // uint32 internal immutable _rewardDurationInMinute = 5; //  For Test 5 Minutes
    uint256 internal _rewardPhase;

    address[] internal _userAddresses;
    mapping(address => UserInfo) internal _users;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardDistributed(uint256 phase, uint256 rewardTime, uint256 amount, uint256 validSupply);
    event UserRewardDistributed(address indexed user, uint256 phase, uint256 rewardTime, uint256 amount, uint256 validSupply, uint256 poolAmount, uint256 poolValidSupply);
    event OwnershipTransferred(address indexed currentOwner, address indexed newOwner);

    constructor(address stakingToken, address rewardToken) {
        require(stakingToken != rewardToken, "RewardPool : stakingToken and rewardToken must be different addresses");
        _stakingToken = IYidocyToken(stakingToken);
        _rewardToken = IERC20(rewardToken);
    }

    //
    // MODIFIER FUNCTIONS
    //
    modifier onlyAdmin() {        
        require(_stakingToken.isAdmin(msg.sender), "RewardPool : Restricted to admins.");
        _;
    }

    //
    // VIEW FUNCTIONS
    //
    function totalSupply() external view returns(uint256) {
        return _totalSupply;
    }

    function validSupplies() external view returns(uint256[] memory validSuppliesPhaseList, uint256[] memory validSuppliesAmountList) {
        validSuppliesPhaseList = new uint256[](_validSupplies.length);
        validSuppliesAmountList = new uint256[](_validSupplies.length);
        uint256 validSuppliesLength = _validSupplies.length;
        for (uint256 i = 0; i < validSuppliesLength; i++) {
            validSuppliesPhaseList[i] = _validSupplies[i].phase;
            validSuppliesAmountList[i] = _validSupplies[i].amount;
        }
    }

    function getRewardInfo(uint256 nowTimestamp) external view returns (uint256 lastRewardTime, uint32 rewardDurationInMinute, uint256 rewardPhase, uint256 nowRewardPhase) {
        lastRewardTime = _lastRewardTime;
        rewardDurationInMinute = _rewardDurationInMinute;
        rewardPhase = _rewardPhase;
        nowRewardPhase = getNowRewardPhase(nowTimestamp);
    }

    function getUserStakingBalance(address account) external view override returns(uint256) {
        return _users[account].stakingBalance;
    }

    function getUserInfo(address account) external view returns(uint256 userStakingBalance, uint256 userRewardBalance,
                            uint256[] memory validSuppliesPhaseList, uint256[] memory validSuppliesAmountList) {
        userStakingBalance = _users[account].stakingBalance;
        uint256 userRewardAmount = getUserRewardAmount(account); 
        userRewardBalance = 0;
        if (userRewardAmount > _users[account].rewardedAmount) {
            userRewardBalance =  userRewardAmount - _users[account].rewardedAmount;
        }
        validSuppliesPhaseList = new uint256[](_users[account].validSupplies.length);
        validSuppliesAmountList = new uint256[](_users[account].validSupplies.length);
        for (uint256 i = 0; i < _users[account].validSupplies.length; i++) {
            validSuppliesPhaseList[i] = _users[account].validSupplies[i].phase;
            validSuppliesAmountList[i] = _users[account].validSupplies[i].amount;
        }
    }

    function getPoolInfo() external view returns(address stakingToken, address rewardToken) {
        stakingToken = address(_stakingToken);
        rewardToken = address(_rewardToken);
    }

    function getNowRewardPhase(uint256 nowTimestamp) public view returns(uint256) {
        if (nowTimestamp == 0) {
            nowTimestamp =  block.timestamp;
        }
        uint32 rewardDurationInMinute = _rewardDurationInMinute;
        uint256 lastRewardTime = _lastRewardTime;
        if (nowTimestamp == 0 || lastRewardTime == 0 || rewardDurationInMinute == 0) {
            return 0;
        }
        uint256 nowRewardTime =  uint256(nowTimestamp/(rewardDurationInMinute*60))*(rewardDurationInMinute*60);
        if (nowRewardTime == lastRewardTime) {
            return _rewardPhase;
        }
        return _rewardPhase + uint256((nowRewardTime-lastRewardTime)/(rewardDurationInMinute*60));
    }

    //
    // TRANSACTION FUNCTIONS
    //
    function deposit(address staker, uint256 amount) external override {
        require(amount > 0, "RewardPool: deposit amount should over 0");
        require(msg.sender == address(_stakingToken), "RewardPool: deposit caller is limited to YidocyToken");

        _totalSupply += amount;
        if (!_users[staker].exist) {
            _users[staker].exist = true;
            _userAddresses.push(staker);
        }
        _users[staker].stakingBalance += amount;
        // Initialize lastRewardTime in case first deposit
        uint256 nowTimestamp = block.timestamp;
        if (_lastRewardTime == 0) {
            _lastRewardTime =  uint256(nowTimestamp/(_rewardDurationInMinute*60))*(_rewardDurationInMinute*60);
         }

        uint256 myRewardPhase = getNowRewardPhase(nowTimestamp)+1;
        
        // Set user's Next Effective Supply
        if (_users[staker].validSupplies.length == 0) {
            for (uint256 i = _rewardPhase; i <= myRewardPhase; i++) {
                _users[staker].validSupplies.push(ValidSupply(i, 0));
            }
        } else if (_users[staker].validSupplies[_users[staker].validSupplies.length-1].phase < myRewardPhase) {
            ValidSupply memory lastValidSupply = _users[staker].validSupplies[_users[staker].validSupplies.length-1];
            for (uint256 i = _users[staker].validSupplies[_users[staker].validSupplies.length-1].phase+1; i <= myRewardPhase; i++) {
                _users[staker].validSupplies.push(ValidSupply(i, lastValidSupply.amount));
            }
        }
        _users[staker].validSupplies[_users[staker].validSupplies.length-1].amount += amount;

        // Set rewardPool's Next Effective Supply
        if (_validSupplies.length == 0) {
            for (uint256 i = _rewardPhase; i <= myRewardPhase; i++) {
                _validSupplies.push(ValidSupply(i, 0));
            }
        } else if (_validSupplies[_validSupplies.length-1].phase < myRewardPhase) {
            ValidSupply memory lastValidSupply = _validSupplies[_validSupplies.length-1];
            for (uint256 i = _validSupplies[_validSupplies.length-1].phase+1; i <= myRewardPhase; i++) {
                _validSupplies.push(ValidSupply(i, lastValidSupply.amount));
            }
        }
        _validSupplies[_validSupplies.length-1].amount += amount;

        emit Deposited(staker, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "RewardPool: Cannot withdraw 0");
        require(amount <= _users[msg.sender].stakingBalance, "RewardPool: Cannot withdraw over my staked amount");
        require(amount <= _totalSupply, "RewardPool: Cannot withdraw over total staked amount");

        require(_stakingToken.transfer(msg.sender, amount));
        _totalSupply -= amount;
        _users[msg.sender].stakingBalance -= amount;

        uint256 myRewardPhase = getNowRewardPhase(block.timestamp);
        if (_users[msg.sender].validSupplies[_users[msg.sender].validSupplies.length-1].phase < myRewardPhase) {
            ValidSupply memory lastValidSupply = _users[msg.sender].validSupplies[_users[msg.sender].validSupplies.length-1];
            for (uint256 i = _users[msg.sender].validSupplies[_users[msg.sender].validSupplies.length-1].phase+1; i <= myRewardPhase; i++) {
                _users[msg.sender].validSupplies.push(ValidSupply(i, lastValidSupply.amount));
            }
        }
        uint256 userSuppliesLength = _users[msg.sender].validSupplies.length;
        if (userSuppliesLength >= 2 && _users[msg.sender].validSupplies[userSuppliesLength-1].phase == myRewardPhase+1) {
            uint256 tempAmount = amount;
            uint256 nextOnlyAmount = _users[msg.sender].validSupplies[userSuppliesLength-1].amount - _users[msg.sender].validSupplies[userSuppliesLength-2].amount;
            _users[msg.sender].validSupplies[userSuppliesLength-1].amount -= tempAmount;
            if (tempAmount >= nextOnlyAmount) {
                tempAmount -= nextOnlyAmount;
                if (_users[msg.sender].validSupplies[userSuppliesLength-2].amount >= tempAmount) {
                    _users[msg.sender].validSupplies[userSuppliesLength-2].amount -= tempAmount;
                }
            }
        } else {
            _users[msg.sender].validSupplies[userSuppliesLength-1].amount -= amount;
        }

        if (_validSupplies[_validSupplies.length-1].phase < myRewardPhase) {
            ValidSupply memory lastValidSupply = _validSupplies[_validSupplies.length-1];
            for (uint256 i = _validSupplies[_validSupplies.length-1].phase+1; i <= myRewardPhase; i++) {
                _validSupplies.push(ValidSupply(i, lastValidSupply.amount));
            }
        }
        uint256 suppliesLength = _validSupplies.length;
        if (suppliesLength >= 2 && _validSupplies[suppliesLength-1].phase == myRewardPhase+1) {
            uint256 tempAmount = amount;
            uint256 nextOnlyAmount = _validSupplies[suppliesLength-1].amount - _validSupplies[suppliesLength-2].amount;
            _validSupplies[suppliesLength-1].amount -= tempAmount;
            if (tempAmount >= nextOnlyAmount) {
                tempAmount -= nextOnlyAmount;
                if (_validSupplies[suppliesLength-2].amount >= tempAmount) {
                    _validSupplies[suppliesLength-2].amount -= tempAmount;
                }
            }
        } else {
            _validSupplies[suppliesLength-1].amount -= amount;
        }
        emit Withdrawn(msg.sender, amount);
    }

    function claim() external {
        uint256 userRewardAmount = getUserRewardAmount(msg.sender); 
        uint256 userRewardBalance = 0;
        if (userRewardAmount > _users[msg.sender].rewardedAmount) {
            userRewardBalance =  userRewardAmount - _users[msg.sender].rewardedAmount;
        }
        require(userRewardBalance > 0, "RewardPool: Staker's Reward Balance must be greater than zero");
        if (_rewardToken.transfer(msg.sender, userRewardBalance)) {
            _users[msg.sender].rewardedAmount += userRewardBalance;
            emit RewardPaid(msg.sender, userRewardBalance);
        }
    }

    function notifyReward(uint256 amount) external override onlyAdmin {
        uint256 rewardTime = uint256(block.timestamp);
        require(getNowRewardPhase(rewardTime) > _rewardPhase, "RewardPool: distribution is not ready");
        uint256 currentPhase = _rewardPhase;
        uint256 validSupply = 0;
        if (_validSupplies[0].phase == currentPhase) {
            validSupply = _validSupplies[0].amount;
        }
        _rewardDists.push(RewardDist(
            currentPhase,
            rewardTime,
            amount,
            validSupply
        ));
        emit RewardDistributed(currentPhase, rewardTime, amount, validSupply);

        uint256 validSupplyLength = _validSupplies.length;
        if (_validSupplies[0].phase == currentPhase) {
            if (validSupplyLength == 1) {
                _validSupplies[0].phase++;
            } else {
                for (uint i = 0; i < validSupplyLength-1; i++){
                    _validSupplies[i] = _validSupplies[i+1];
                }
                _validSupplies.pop();
            }
        }
        _rewardPhase++;
        _lastRewardTime = uint256(_lastRewardTime+_rewardDurationInMinute*60);

        uint256 myRewardPhase = getNowRewardPhase(block.timestamp);
        // Set rewardPool's Next Effective Supply
        if (_validSupplies.length == 0) {
            for (uint256 i = _rewardPhase; i <= myRewardPhase; i++) {
                _validSupplies.push(ValidSupply(i, 0));
            }
        } else if (_validSupplies[_validSupplies.length-1].phase < myRewardPhase) {
            ValidSupply memory lastValidSupply = _validSupplies[_validSupplies.length-1];
            for (uint256 i = _validSupplies[_validSupplies.length-1].phase+1; i <= myRewardPhase; i++) {
                _validSupplies.push(ValidSupply(i, lastValidSupply.amount));
            }
        }
    }

    function BalanceOfStakingToken() external view returns(uint256) {
        return _stakingToken.balanceOf(address(this));
    }
    function BalanceOfRewardToken() external view returns(uint256) {
        return _rewardToken.balanceOf(address(this));
    }

    function getUserRewardAmount(address userAddress) internal view returns(uint256) {
        uint256 userRewardAmount = 0;
        UserInfo memory user = _users[userAddress];
        if (user.validSupplies.length == 0 || _rewardDists.length == 0) {
            return userRewardAmount;
        }

        for (uint256 i = 0; i < user.validSupplies.length; i++) {
            if (user.validSupplies[i].phase >= _rewardPhase) {
                break;
            }
            if (user.validSupplies[i].amount == 0) {
                continue;
            }
            for (uint256 j = 0; j < _rewardDists.length; j++) {
                if (_rewardDists[j].phase == user.validSupplies[i].phase) {
                    if (_rewardDists[j].amount > 0 && _rewardDists[j].validSupply > 0) {
                        userRewardAmount += user.validSupplies[i].amount * _rewardDists[j].amount * 1e18 / _rewardDists[j].validSupply / 1e18;
                    }
                    break;
                }
            }
        }
        ValidSupply memory lastValidSupply = user.validSupplies[user.validSupplies.length-1];
        for (uint256 i = user.validSupplies[user.validSupplies.length-1].phase+1; lastValidSupply.amount > 0 && i < _rewardPhase; i++) {
            for (uint256 j = 0; j < _rewardDists.length; j++) {
                if (_rewardDists[j].phase == i) {
                    if (_rewardDists[j].amount > 0 && _rewardDists[j].validSupply > 0) {
                        userRewardAmount += lastValidSupply.amount * _rewardDists[j].amount * 1e18 / _rewardDists[j].validSupply / 1e18;
                    }
                    break;
                }
            }
        }
        return userRewardAmount;
    }
    function getUserRewardDistHistory(address userAddress, uint256 fromPhase) external view returns(
        uint256[] memory rewardDistPhaseList, 
        uint256[] memory rewardDistRewardTimeList,
        uint256[] memory userValidSuplyList,
        uint256[] memory userRewardAmountList
    ) {

        UserInfo memory user = _users[userAddress];
        require(user.validSupplies.length > 0 && _rewardDists.length > 0, "RewardPool : No UserRewardDistHistory exist");
        require(fromPhase < _rewardPhase, "RewardPool : UserRewardDistHistory could not be below now reward phase");

        ValidSupply memory lastValidSupply = user.validSupplies[user.validSupplies.length-1];
        uint256 userHistoryLength = 0;
        if (_rewardPhase > lastValidSupply.phase) {
            userHistoryLength = user.validSupplies.length + ((_rewardPhase-1) -lastValidSupply.phase);
        } else {
            userHistoryLength = user.validSupplies.length - (lastValidSupply.phase - (_rewardPhase-1));
        }
        if (_rewardPhase - fromPhase < userHistoryLength) {
            userHistoryLength = _rewardPhase - fromPhase;
        }

        rewardDistPhaseList = new uint256[](userHistoryLength);
        rewardDistRewardTimeList = new uint256[](userHistoryLength);
        userValidSuplyList = new uint256[](userHistoryLength);
        userRewardAmountList = new uint256[](userHistoryLength);

        uint256 historyIndex = 0;
        for (uint256 i = fromPhase; i < user.validSupplies.length && historyIndex < userHistoryLength; i++) {
            if (user.validSupplies[i].phase >= _rewardPhase) {
                break;
            }
            for (uint256 j = 0; j < _rewardDists.length; j++) {
                if (_rewardDists[j].phase == user.validSupplies[i].phase) {
                    uint256 userRewardAmount = 0;
                    if (user.validSupplies[i].amount > 0) {
                        if (_rewardDists[j].amount > 0 && _rewardDists[j].validSupply > 0) {
                            userRewardAmount = user.validSupplies[i].amount * _rewardDists[j].amount * 1e18 / _rewardDists[j].validSupply / 1e18;
                        }
                    }
                    rewardDistPhaseList[historyIndex] = _rewardDists[j].phase;
                    rewardDistRewardTimeList[historyIndex] = _rewardDists[j].rewardTime;
                    userValidSuplyList[historyIndex] = user.validSupplies[i].amount;
                    userRewardAmountList[historyIndex] = userRewardAmount;
                    break;
                }
            }
            historyIndex++;
        }
        for (uint256 i = user.validSupplies[user.validSupplies.length-1].phase+1; i < _rewardPhase && historyIndex < userHistoryLength; i++) {
            if (fromPhase > i) {
                continue;
            }
            for (uint256 j = 0; j < _rewardDists.length; j++) {
                if (_rewardDists[j].phase == i) {
                    uint256 userRewardAmount = 0;
                    if (_rewardDists[j].amount > 0 && _rewardDists[j].validSupply > 0) {
                        userRewardAmount = lastValidSupply.amount * _rewardDists[j].amount * 1e18 / _rewardDists[j].validSupply / 1e18;
                    }
                    rewardDistPhaseList[historyIndex] = _rewardDists[j].phase;
                    rewardDistRewardTimeList[historyIndex] = _rewardDists[j].rewardTime;
                    userValidSuplyList[historyIndex] = lastValidSupply.amount;
                    userRewardAmountList[historyIndex] = userRewardAmount;
                    break;
                }
            }
            historyIndex++;
        }
    }
}
