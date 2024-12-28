// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./Arbiter.sol";
import "./Restricted.sol";

contract ArbiterManagement is Restricted {
    bool private initialized;
    address[] private arbiters;
    address[] private blockedArbiters;
    mapping(address => bool) private isArbiter;
    mapping(address => address) private arbiterRegistry;

    event ArbiterAdded(address indexed arbiter);
    event ArbiterPenalized(
        address indexed arbiter,
        address indexed token,
        uint256 amount
    );
    event ArbiterSuspended(address indexed arbiter, string reason);
    event ArbiterBlocked(address indexed arbiter, string reason);

    constructor(address _multiSig) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
    }

    /**
     * @dev Initialize the contract with the addresses of the contracts that need to be granted the CONTRACT_ROLE
     * @param contracts The addresses of the contracts that need to be granted the CONTRACT_ROLE
     */
    function initialize(
        Requestor[] calldata contracts
    ) external onlyRole(MULTISIG_ROLE) {
        require(!initialized, "Contract already initialized");
        _initializeRoles(contracts);
        initialized = true;
    }

    /**
     * @dev Add an arbiter
     * @param _arbiter The address of the arbiter to be added
     */
    function addArbiter(
        address _arbiter,
        Requestor[] calldata contracts
    ) external onlyRole(WRITE_ACCESS_ROLE) returns (address) {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiter[_arbiter], "Arbiter already added");
        // set the arbiter to true in the isArbiter mapping
        isArbiter[_arbiter] = true;
        // create a new arbiter contract
        Arbiter arbiterContract = new Arbiter(_arbiter, contracts);
        // add the arbiter to the arbiters array
        arbiters.push(address(arbiterContract));
        // add the arbiter to the arbiterRegistry mapping
        arbiterRegistry[_arbiter] = address(arbiterContract);
        emit ArbiterAdded(_arbiter);
        // return the address of the arbiter contract
        return address(arbiterContract);
    }

    /**
     * @dev Suspend an arbiter
     * @param _arbiter The address of the arbiter to be suspended
     * @param reason The reason for suspending the arbiter
     */
    function suspendArbiter(
        address _arbiter,
        string calldata reason
    ) external onlyRole(MULTISIG_ROLE) {
        require(isArbiter[_arbiter], "Not an arbiter");
        // create pointer to the arbiter contract and set to suspended
        address arbiterContract = arbiterRegistry[_arbiter];
        Arbiter arbiter = Arbiter(arbiterContract);
        arbiter.setArbiterStatus(Arbiter.ArbiterStatus.SUSPENDED);
        // emit ArbiterSuspended event
        emit ArbiterSuspended(_arbiter, reason);
    }

    /**
     * @dev Block an arbiter
     * @param _arbiter The address of the arbiter to be blocked
     * @param _reason The reason for blocking the arbiter
     */
    function blockArbiter(
        address _arbiter,
        string calldata _reason
    ) external onlyRole(MULTISIG_ROLE) {
        require(isArbiter[_arbiter], "Not an arbiter");
        // create pointer to the arbiter contract and set to blocked
        address arbiterContract = arbiterRegistry[_arbiter];
        Arbiter arbiter = Arbiter(arbiterContract);
        arbiter.setArbiterStatus(Arbiter.ArbiterStatus.BLOCKED);
        // add the arbiter to the blockedArbiters array
        blockedArbiters.push(_arbiter);
        // emit ArbiterBlocked event
        emit ArbiterBlocked(_arbiter, _reason);
    }

    function getArbiters() external view returns (address[] memory) {
        return arbiters;
    }

    function getBlockedArbiters() external view returns (address[] memory) {
        return blockedArbiters;
    }

    function getArbiter(address _arbiter) external view returns (address) {
        require(isArbiter[_arbiter], "Not an arbiter");
        return arbiterRegistry[_arbiter];
    }

    function getArbiterStatus(
        address _arbiter
    ) external view returns (Arbiter.ArbiterStatus) {
        require(isArbiter[_arbiter], "Not an arbiter");

        address arbiterContract = arbiterRegistry[_arbiter];
        Arbiter arbiter = Arbiter(arbiterContract);
        return arbiter.getStatus();
    }

    function getArbiterCount() external view returns (uint256) {
        return arbiters.length;
    }

    function isRegistered(address _arbiter) external view returns (bool) {
        return isArbiter[_arbiter];
    }
}
