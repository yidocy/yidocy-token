// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IYidocyToken.sol";

contract MultiSignWallet {
    uint256 internal _requireds;
    IYidocyToken internal immutable _stakingToken;

    struct Transaction {
        address destination;
        uint256 value;
        bool executed;
        bytes data;
        uint256 confirmationCount;
    }
    mapping(uint256 => Transaction) internal transactions;
    mapping(uint256 => mapping(address => bool)) internal confirmations;
    uint256 internal transactionCount;

    modifier onlyAdmin() {
        require(_stakingToken.isAdmin(msg.sender), "MultiSignWallet : Not an admin");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactionCount, "MultiSignWallet : Transaction does not exist");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address admin) {
        require(!confirmations[transactionId][admin], "MultiSignWallet : Transaction already confirmed");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "MultiSignWallet : Transaction already executed");
        _;
    }

    event Deposit(address indexed sender, uint256 value);
    event SubmitTransaction(address indexed admin, uint256 indexed transactionId, address indexed destination, uint256 value, bytes data);
    event ConfirmTransaction(address indexed admin, uint256 indexed transactionId);
    event RevokeConfirmation(address indexed admin, uint256 indexed transactionId);
    event ExecuteTransaction(address indexed admin, uint256 indexed transactionId);

    constructor(address stakingToken, uint256 requireds) {
        require(stakingToken != address(0), "MultiSignWallet : Invalid staking token address");
        _stakingToken = IYidocyToken(stakingToken);
        require(requireds > 0 && requireds <= _stakingToken.adminRoleMembersCount(), "MultiSignWallet : Invalid number of required confirmations");
        _requireds = requireds;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function balanceOf() external view returns(uint256) {
        return _stakingToken.balanceOf(address(this));
    }
    
    function submitTransaction(address destination, uint256 value, bytes memory data) public onlyAdmin {
        uint256 transactionId = addTransaction(destination, value, data);
        emit SubmitTransaction(
            msg.sender,
            transactionId,
            destination,
            value,
            data
        );
        confirmTransaction(transactionId); // 자동으로 제출한 트랜잭션을 확인합니다.
    }

    function confirmTransaction(uint256 transactionId) public onlyAdmin transactionExists(transactionId) notConfirmed(transactionId, msg.sender) {
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmationCount += 1;
        emit ConfirmTransaction(msg.sender, transactionId);
        if (transactions[transactionId].confirmationCount >= _requireds && !transactions[transactionId].executed) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint256 transactionId) public onlyAdmin transactionExists(transactionId) notExecuted(transactionId) {
        Transaction storage txn = transactions[transactionId];
        require(txn.confirmationCount >= _requireds, "MultiSignWallet : Cannot execute transaction: insufficient confirmations");
        txn.executed = true;
        (bool success, ) = address(_stakingToken).call(txn.data); // MyToken 함수를 호출
        require(success, "MultiSignWallet : Transaction execution failed");
        emit ExecuteTransaction(msg.sender, transactionId);
    }

    function revokeConfirmation(uint256 transactionId) public onlyAdmin transactionExists(transactionId) notExecuted(transactionId) {
        require(confirmations[transactionId][msg.sender], "MultiSignWallet : Transaction not confirmed");
        confirmations[transactionId][msg.sender] = false;
        transactions[transactionId].confirmationCount -= 1;
        emit RevokeConfirmation(msg.sender, transactionId);
    }

    function addTransaction(address destination, uint256 value, bytes memory data) internal returns (uint256) {
        uint256 transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            executed: false,
            data: data,
            confirmationCount: 0
        });
        transactionCount += 1;
        return transactionId;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getTransaction(uint256 transactionId) public view returns (
        address destination,
        uint256 value,
        bool executed,
        bytes memory data,
        uint256 confirmationCount) {
        Transaction storage txn = transactions[transactionId];
        return (
            txn.destination,
            txn.value,
            txn.executed,
            txn.data,
            txn.confirmationCount
        );
    }

    function getConfirmations(uint256 transactionId) public view returns (address[] memory) {
        uint256 count = 0;
        address[] memory adminRoleMembers = _stakingToken.getAdminRoleMembers();
        for (uint256 i = 0; i < adminRoleMembers.length; i++) {
            if (confirmations[transactionId][adminRoleMembers[i]]) {
                count += 1;
            }
        }

        address[] memory _confirmations = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < adminRoleMembers.length; i++) {
            if (confirmations[transactionId][adminRoleMembers[i]]) {
                _confirmations[index] = adminRoleMembers[i];
                index += 1;
            }
        }

        return _confirmations;
    }
}