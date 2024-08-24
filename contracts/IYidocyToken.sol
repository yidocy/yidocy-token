// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
interface IYidocyToken is IERC20 {
    function isAdmin(address account) external view returns (bool);
    function adminRoleMembersCount() external view returns (uint256);
    function getAdminRoleMembers() external view returns (address[] memory adminRoleMembers);
}