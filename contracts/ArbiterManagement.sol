// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ArbiterManagement is Ownable {
    address[] public arbiters;
    address[] public blockedArbiters;
    mapping(address => bool) public isArbiter;
    mapping(address => address) public arbiterRegistry;

    event ArbiterAdded(address indexed arbiter);
    event ArbiterBlocked(address indexed arbiter, string reason);

    constructor(address _multiSig) Ownable(_multiSig) {}

    /**
     * @dev Add an arbiter
     * @param _arbiter The address of the arbiter to be added
     */
    function addArbiter(address _arbiter) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiter[_arbiter], "Arbiter already added");
        arbiters.push(_arbiter);
        isArbiter[_arbiter] = true;
        emit ArbiterAdded(_arbiter);
    }

    /**
     * @dev Block an arbiter
     * @param _arbiter The address of the arbiter to be blocked
     * @param _reason The reason for blocking the arbiter
     */
    function blockArbiter(
        address _arbiter,
        string memory _reason
    ) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(isArbiter[_arbiter], "Not an arbiter");
        blockedArbiters.push(_arbiter);
        emit ArbiterBlocked(_arbiter, _reason);
    }

    function getArbiters() external view returns (address[] memory) {
        return arbiters;
    }

    function getBlockedArbiters() external view returns (address[] memory) {
        return blockedArbiters;
    }

    function getArbiter(address _arbiter) external view returns (address) {
        return arbiterRegistry[_arbiter];
    }

    function getArbiterCouint() external view returns (uint256) {
        return arbiters.length;
    }
}
