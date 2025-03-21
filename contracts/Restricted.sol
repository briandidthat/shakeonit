// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IShakeOnIt.sol";

abstract contract Restricted is AccessControl {
    bytes32 public constant MULTISIG_ROLE = keccak256("MULTISIG_ROLE");
    bytes32 public constant BET_CONTRACT_ROLE = keccak256("BET_CONTRACT_ROLE");

    modifier hasCorrectRole(bytes32 role) {
        require(
            hasRole(role, msg.sender),
            "Restricted: caller is missing the required role"
        );
        _;
    }
}
