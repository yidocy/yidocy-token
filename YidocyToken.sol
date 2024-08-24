// SPDX-License-Identifier: NO License

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./IRewardPool.sol";

contract YidocyToken is ERC20, AccessControl {
    uint256 internal immutable _supplyCap;
    IRewardPool internal _rewardPool;

    struct VestingSchedule {
        uint256 validFromDate;
        uint256 amount;
    }
    struct LockupInfo {
        uint256 lockupAmount;
        uint256 code; // 1: Team, 2: Advisor, 3: Private Sale
        address rewardPoolAddress;
        VestingSchedule[] vestingSchedules;
    }
    address[] internal _userLockupAddresses;
    mapping(address => LockupInfo) internal _userLockups;

    address[] internal _adminRoleMembers;

    struct AdminRoleRequest {
        address newAdmin;
        address revokeAdmin;
        uint256 action; // 1: add, 2: revoke, 3: transfer
        uint256 status; // 0: requested, 1: executed, 2: rejected
        address requestedAdmin;
        address approvedAdmin;
        address rejectedAdmin;
    }
    mapping(uint256 => AdminRoleRequest) internal _adminRoleRequests;
    uint256 internal _adminRoleRequestCount;

    event AdminRoleTransferred(address indexed currentAdmin, address indexed newAdmin, uint256 requestId);
    event AdminRoleAdded(address indexed performedAdmin, address indexed newAdmin, uint256 requestId);
    event AdminRoleRevoked(address indexed performedAdmin, address indexed revokedAdmin, uint256 requestId);
    event AdminRoleRequested(address indexed requesteAdmin, uint256 action, uint256 requestId);
    event AdminRoleRejected(address indexed rejectedAdmin, uint256 action, uint256 requestId);

    modifier onlyAdmin() {
        require(_isAdmin(msg.sender), "YidocyToken : Restricted to admins.");
        _;
    }

    constructor(address[] memory multiAdminRoles, uint256 supplyCap) ERC20("Yidocy", "YIDO") {
        require(multiAdminRoles.length > 1, "YidocyToken : Number of multiAdminRoles must be over 1");
        for (uint256 i = 0; i < multiAdminRoles.length; i++) {
            require(multiAdminRoles[i] != address(0), "YidocyToken : multiAdminRole address could not be zero");
            require(multiAdminRoles[i] != msg.sender, "YidocyToken : Except contructor, number of multiAdminRoles must be over 1");
        }
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _adminRoleMembers.push(msg.sender);
        for (uint256 i = 0; i < multiAdminRoles.length; i++) {
            _adminRoleMembers.push(multiAdminRoles[i]);
            _grantRole(DEFAULT_ADMIN_ROLE, multiAdminRoles[i]);
        }
        _supplyCap = supplyCap;
        _mint(msg.sender, _supplyCap);    
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function getLockupUsers() external view returns(address[] memory) {
        return _userLockupAddresses;
    }

    function getUserLockup(address account) external view returns(
        uint256 lockupAmount,
        uint256 code,
        uint256[] memory vestingValidFromDateList,
        uint256[] memory vestingAmountList
    ) {
        lockupAmount = 0;
        LockupInfo memory userLockup = _userLockups[account];
        if (userLockup.lockupAmount > 0) {
            lockupAmount = userLockup.lockupAmount;
            code = userLockup.code;
            vestingValidFromDateList = new uint256[](userLockup.vestingSchedules.length);
            vestingAmountList = new uint256[](userLockup.vestingSchedules.length);
            for (uint256 i = 0; i < userLockup.vestingSchedules.length; i++) {
                vestingValidFromDateList[i] = userLockup.vestingSchedules[i].validFromDate;
                vestingAmountList[i] = userLockup.vestingSchedules[i].amount;
            }
        }
    }

    function transferableAmount(address sender, address recipient) internal view returns (uint256){
        uint256 senderBalanceOf = balanceOf(sender);
        LockupInfo memory userLockup = _userLockups[sender];
        if (userLockup.lockupAmount == 0 || userLockup.rewardPoolAddress == recipient) {
            return senderBalanceOf;
        }
        uint256 senderStakingBalanceOf = IRewardPool(userLockup.rewardPoolAddress).getUserStakingBalance(sender);
        uint256 amount = senderBalanceOf + senderStakingBalanceOf;
        uint256 nowTimestamp = uint256(block.timestamp);
        uint256 vestingScheduleLength = userLockup.vestingSchedules.length;
        for (uint256 i = 0; i < vestingScheduleLength; i++) {
            if (userLockup.vestingSchedules[i].validFromDate > nowTimestamp) {
                if (amount < userLockup.vestingSchedules[i].amount) {
                    return 0;
                }
                amount -= userLockup.vestingSchedules[i].amount;
            }
        }
        if (amount >= senderBalanceOf) {
            return senderBalanceOf;
        }
        return amount;
    }

    function stakeToken(uint256 amount) external {
        transfer(address(_rewardPool), amount);
        _rewardPool.deposit(msg.sender, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(transferableAmount(_msgSender(), recipient)  >= amount, "YidocyToken : Cannot transfer more than transferable amount");
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(transferableAmount(sender, recipient)  >= amount, "YidocyToken : Cannot transfer from more than transferable amount");
        return super.transferFrom(sender, recipient, amount);
    }

    function mint() external pure {
        revert("YidocyToken : mint is not supported for this TOKEN!!");
    }
    function setRewardPool(address rewardPool) external onlyAdmin {
        require(address(_rewardPool) == address(0), "YidocyToken : setRewardPool must called once at the deploy time");
        require(rewardPool != address(0), "YidocyToken : RewardPool address is required");
        _rewardPool = IRewardPool(rewardPool);
    }

    function burn() external pure {
        revert("YidocyToken : burn is not supported for this TOKEN!!");
    }

    function setUserLockup(
        address rewardPoolAddress,
        address account,
        uint256 lockupAmount,
        uint8 code, // 1: Team, 2: Advisor, 3: Private Sale
        uint256[] memory vestingValidFromDateList,
        uint256[] memory vestingAmountList
    ) external onlyAdmin {
        if (lockupAmount == 0) {
            delete _userLockups[account];
            uint256 addressLength = _userLockupAddresses.length;
            for (uint256 i = 0; i < addressLength; i++) {
                if (_userLockupAddresses[i] == account) {
                    delete _userLockupAddresses[i];
                    _userLockupAddresses[i] = _userLockupAddresses[addressLength-1];
                    _userLockupAddresses.pop();
                    break;
                }
            }
            return;
        }
        require(vestingValidFromDateList.length == vestingAmountList.length, "YidocyToken : Lockup date list and amount list must be the same length!");
        uint256 vestingTotalAmount = 0;
        for (uint256 i = 0; i < vestingValidFromDateList.length; i++) {
            vestingTotalAmount += vestingAmountList[i];
        }
        require(vestingTotalAmount <= lockupAmount, "YidocyToken : Lockup vesting total amount must be less or equal to the lockup amount!");

        _userLockups[account].lockupAmount = lockupAmount;
        _userLockups[account].code = code;
        _userLockups[account].rewardPoolAddress = rewardPoolAddress;
        delete _userLockups[account].vestingSchedules;
        for (uint256 i = 0; i < vestingValidFromDateList.length; i++) {
            _userLockups[account].vestingSchedules.push(VestingSchedule(vestingValidFromDateList[i], vestingAmountList[i]));
        }
        bool addressFound = false;
        uint256 userLockupAddressLength = _userLockupAddresses.length;
        for (uint256 i = 0; i < userLockupAddressLength; i++) {
            if (_userLockupAddresses[i] == account) {
                addressFound = true;
                break;
            }
        }
        if (!addressFound) {
            _userLockupAddresses.push(account);
        }
    }

    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
    }
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
    } 
    function renounceRole(bytes32 role, address callerConfirmation) public virtual override {
    }

    function _isAdmin(address account) internal view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }
    function isAdmin(address account) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }
    function _adminRoleMembersCount() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _adminRoleMembers.length; i++) {
            if (_adminRoleMembers[i] != address(0)) {
                count++;
            }
        }
        return count;
    }
    function adminRoleMembersCount() external view returns (uint256) {
        return _adminRoleMembersCount();
    }
    function getAdminRoleMembers() external view returns (address[] memory adminRoleMembers) {
        adminRoleMembers = new address[](_adminRoleMembersCount());
        uint256 index = 0;
        for (uint256 i = 0; i < _adminRoleMembers.length; i++) {
            if (_adminRoleMembers[i] != address(0)) {
                adminRoleMembers[index++] = _adminRoleMembers[i];
            }
        }
    }
    function getAdminRoleRequestCount() external view returns(uint256) {
        return _adminRoleRequestCount;
    }
    
    function getAdminRoleRequest(uint256 requestId) external view returns (
        address newAdmin,
        address revokeAdmin,
        uint256 action,
        uint256 status,
        address requestedAdmin,
        address approvedAdmin,
        address rejectedAdmin       
    ) {
        require(requestId < _adminRoleRequestCount, "YidocyToken : requestId does not exist");
        newAdmin = _adminRoleRequests[requestId].newAdmin;
        revokeAdmin = _adminRoleRequests[requestId].revokeAdmin;
        action = _adminRoleRequests[requestId].action;
        status = _adminRoleRequests[requestId].status;
        requestedAdmin = _adminRoleRequests[requestId].requestedAdmin;
        approvedAdmin = _adminRoleRequests[requestId].approvedAdmin;
        rejectedAdmin = _adminRoleRequests[requestId].newAdmin;
    }
    function requestTransferAdminRole(address newAdmin) external onlyAdmin returns(uint256) {
        require(newAdmin != address(0), "YidocyToken : Cannot transfer admin role to zero address");
        require(newAdmin != msg.sender, "YidocyToken : Cannot transfer admin role to the same address");
        require(_adminRoleRequestCount == 0 || _adminRoleRequests[_adminRoleRequestCount-1].status > 0, "YidocyToken : Previous AdminRole Request is pending");
        uint256 requestId = _adminRoleRequestCount;
        _adminRoleRequestCount += 1;
        _adminRoleRequests[requestId] = AdminRoleRequest({
            newAdmin: newAdmin,
            revokeAdmin: msg.sender,
            action: 3,
            status: 0,
            requestedAdmin: msg.sender,
            approvedAdmin: address(0),
            rejectedAdmin: address(0)
        });
        emit AdminRoleRequested(msg.sender, 3, requestId);
        return requestId;
    }
    function requestAddAdminRole(address newAdmin) external onlyAdmin returns(uint256) {
        require(newAdmin != address(0), "YidocyToken : Cannot add admin role for zero address");
        require(newAdmin != msg.sender, "YidocyToken : Cannot add admin role for the same address");
        require(_adminRoleRequestCount == 0 || _adminRoleRequests[_adminRoleRequestCount-1].status > 0, "YidocyToken : Previous AdminRole Request is pending");
        uint256 requestId = _adminRoleRequestCount;
        _adminRoleRequestCount += 1;
        _adminRoleRequests[requestId] = AdminRoleRequest({
            newAdmin: newAdmin,
            revokeAdmin: address(0),
            action: 1,
            status: 0,
            requestedAdmin: msg.sender,
            approvedAdmin: address(0),
            rejectedAdmin: address(0)
        });
        emit AdminRoleRequested(msg.sender, 1, requestId);
        return requestId;
    }
    function requestRevokeAdminRole(address revokeAdmin) external onlyAdmin returns(uint256) {
        require(revokeAdmin != address(0), "YidocyToken : Cannot add admin role for zero address");
        require(_adminRoleRequestCount == 0 || _adminRoleRequests[_adminRoleRequestCount-1].status > 0, "YidocyToken : Previous AdminRole Request is pending");
        uint256 requestId = _adminRoleRequestCount;
        _adminRoleRequestCount += 1;
        _adminRoleRequests[requestId] = AdminRoleRequest({
            newAdmin: address(0),
            revokeAdmin: revokeAdmin,
            action: 2,
            status: 0,
            requestedAdmin: msg.sender,
            approvedAdmin: address(0),
            rejectedAdmin: address(0)
        });
        emit AdminRoleRequested(msg.sender, 2, requestId);
        return requestId;
    }

    function executeRequestAdminRole(bool approval) external onlyAdmin returns(uint256) {
        require(_adminRoleRequestCount > 0, "YidocyToken : There is no excutable AdminRoleRequest");
        uint256 requestId = _adminRoleRequestCount-1;
        require(_adminRoleRequestCount > 0 && _adminRoleRequests[requestId].status == 0, "YidocyToken : No AdminRole Request is requested");
        require(msg.sender != _adminRoleRequests[requestId].requestedAdmin, "YidocyToken : Execute Request must be the other amdinRoler");
        if (approval) {
            _adminRoleRequests[requestId].status = 1;
            _adminRoleRequests[requestId].approvedAdmin = msg.sender;
            _adminRoleRequests[requestId].rejectedAdmin = address(0);
            if (_adminRoleRequests[requestId].action == 1) { // add new AdminRole
                _grantRole(DEFAULT_ADMIN_ROLE, _adminRoleRequests[requestId].newAdmin);
                _adminRoleMembers.push(_adminRoleRequests[requestId].newAdmin);
                emit AdminRoleAdded(msg.sender, _adminRoleRequests[requestId].newAdmin, requestId);
            } else if (_adminRoleRequests[requestId].action == 2) { // revoke AdminRole
                _revokeRole(DEFAULT_ADMIN_ROLE, _adminRoleRequests[requestId].revokeAdmin);
                for (uint256 i = 0; i < _adminRoleMembers.length; i++) {
                    if (_adminRoleMembers[i] == _adminRoleRequests[requestId].revokeAdmin) {
                        _adminRoleMembers[i] = address(0);
                        break;
                    }
                }        
                emit AdminRoleRevoked(msg.sender, _adminRoleRequests[requestId].revokeAdmin, requestId);
            } else if (_adminRoleRequests[requestId].action == 3) { // transfer AdminRole
                _grantRole(DEFAULT_ADMIN_ROLE, _adminRoleRequests[requestId].newAdmin);
                _revokeRole(DEFAULT_ADMIN_ROLE, _adminRoleRequests[requestId].revokeAdmin);
                for (uint256 i = 0; i < _adminRoleMembers.length; i++) {
                    if (_adminRoleMembers[i] == _adminRoleRequests[requestId].revokeAdmin) {
                        _adminRoleMembers[i] = _adminRoleRequests[requestId].newAdmin;
                        break;
                    }
                }
                emit AdminRoleTransferred(msg.sender, _adminRoleRequests[requestId].newAdmin, requestId);
            }
        } else {
            _adminRoleRequests[requestId].status = 2;
            _adminRoleRequests[requestId].approvedAdmin = address(0);
            _adminRoleRequests[requestId].rejectedAdmin = msg.sender;
            emit AdminRoleRejected(msg.sender, _adminRoleRequests[requestId].action, requestId);
        }
        return requestId;
    }
}
