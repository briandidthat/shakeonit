// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";

contract UserManagement is Ownable {
    address[] public users;
    address[] public userStorageContracts;
    mapping(address => bool) public isUser;
    mapping(address => address) public userStorageRegistry;
    // event to be emitted when a new user is added
    event UserAdded(address indexed user, address indexed userStorage);

    constructor(address _multiSigWallet) Ownable(_multiSigWallet) {}

    /**
     * @dev Add a new user
     * @param _user The address of the user
     */
    function addUser(address _user) external onlyOwner returns (address) {
        require(_user != address(0), "Zero address not allowed");
        require(!isUser[_user], "User already registered");
        // create a new user storage contract and store the address in the user storage registry
        UserStorage userStorage = new UserStorage(_user, address(this));
        userStorageRegistry[_user] = address(userStorage);
        users.push(_user);
        userStorageContracts.push(address(userStorage));
        isUser[_user] = true;
        emit UserAdded(_user, address(userStorage));
        return address(userStorage);
    }

    /**
     * @dev Get the user storage contract address for a user
     * @param _user The address of the user
     */
    function getUserStorage(address _user) external view returns (address) {
        require(isUser[_user], "User not registered");
        return userStorageRegistry[_user];
    }

    /**
     * @dev Get all registered users
     */
    function getUsers() external view returns (address[] memory) {
        return users;
    }

    /**
     * @dev Get all user storage contracts
     */
    function getUserStorageContracts()
        external
        view
        returns (address[] memory)
    {
        return userStorageContracts;
    }

    /**
     * @dev Check if a user is registered
     * @param _user The address of the user
     */
    function isRegistered(address _user) external view returns (bool) {
        return isUser[_user];
    }
}
