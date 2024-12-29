// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IShakeOnIt.sol";

abstract contract Restricted is AccessControl {
    bytes32 public constant MULTISIG_ROLE = keccak256("MULTISIG_ROLE");
    bytes32 public constant WRITE_ACCESS_ROLE = keccak256("WRITE_ACCESS_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    bytes32 public constant BET_CONTRACT_ROLE = keccak256("BET_CONTRACT_ROLE");

    /**
     * @dev Revoke the role from the address
     * @param role The role to be revoked
     * @param account The address from which the role is to be revoked
     */
    function _removeRole(bytes32 role, address account) internal {
        require(hasRole(role, account), "Address does not have the role");
        revokeRole(role, account);
    }
}
