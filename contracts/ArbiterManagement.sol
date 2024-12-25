// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./Arbiter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ArbiterManagement is Ownable {
    address[] public arbiters;
    address[] public blockedArbiters;
    mapping(address => bool) public isArbiter;
    mapping(address => address) public arbiterRegistry;

    event ArbiterAdded(address indexed arbiter);
    event ArbiterPenalized(
        address indexed arbiter,
        address indexed token,
        uint256 amount
    );
    event ArbiterSuspended(address indexed arbiter, string reason);
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
     * @dev Suspend an arbiter
     * @param _arbiter The address of the arbiter to be suspended
     * @param reason The reason for suspending the arbiter
     */
    function suspendArbiter(address _arbiter, string calldata reason) external onlyOwner {
        require(isArbiter[_arbiter], "Not an arbiter");
        Arbiter arbiter = Arbiter(_arbiter);
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
    ) external onlyOwner {
        require(isArbiter[_arbiter], "Not an arbiter");
        // create pointer to the arbiter contract and set to blocked
        Arbiter arbiter = Arbiter(_arbiter);
        arbiter.setArbiterStatus(Arbiter.ArbiterStatus.BLOCKED);
        // add the arbiter to the blockedArbiters array
        blockedArbiters.push(_arbiter);
        // emit ArbiterBlocked event
        emit ArbiterBlocked(_arbiter, _reason);
    }

    /**
     * @dev Penalize an arbiter
     * @param _arbiter The address of the arbiter to be penalized
     * @param _token The address of the token to be penalized
     * @param _amount The amount to be penalized
     */
    function penalizeArbiter(
        address _arbiter,
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(isArbiter[_arbiter], "Not an arbiter");
        // create pointer to the arbiter contract and call the penalize function
        Arbiter arbiter = Arbiter(_arbiter);
        arbiter.penalize(_token, _amount);
        // emit ArbiterPenalized event
        emit ArbiterPenalized(_arbiter, _token, _amount);
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

    function getMultiSig() external view returns (address) {
        return owner();
    }
}
