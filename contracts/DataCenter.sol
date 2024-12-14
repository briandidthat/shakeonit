// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";

contract DataCenter is Ownable {
    address public factory;
    address[] public deployedBets;
    address[] public deployers;
    address[] public arbiters;
    address[] public blockedArbiters;
    mapping(address => bool) public isArbiter;
    mapping(address => bool) public isArbiterBlocked;
    mapping(address => address) public userStorageRegistry;

    function createBet(
        address _betContract,
        address _proposer,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _message
    ) external {
        address userStorageAddress = userStorageRegistry[_proposer];
        UserStorage storageContract;

        if (userStorageAddress == address(0)) {
            storageContract = new UserStorage(_proposer);
            userStorageAddress = address(storageContract);
            userStorageRegistry[_proposer] = userStorageAddress;
        } else {
            storageContract = UserStorage(userStorageAddress);
        }
        // store the new bet in the user storage
        storageContract.createBet(
            _betContract,
            _arbiter,
            _fundToken,
            _amount,
            _deadline,
            _message
        );
    }

    /**
     * @dev Block an arbiter
     * @param _arbiter The address of the arbiter to be blocked
     */
    function blockArbiter(address _arbiter) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiterBlocked[_arbiter], "Arbiter already blocked");
        // block the specified arbiter
        blockedArbiters.push(_arbiter);
    }

    /**
     * @dev Add an arbiter
     * @param _arbiter The address of the arbiter to be added
     */
    function addArbiter(address _arbiter) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiter[_arbiter], "Arbiter already added");
        // add the specified arbiter
        arbiters.push(_arbiter);
    }
}
