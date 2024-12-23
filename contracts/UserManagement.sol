// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./interfaces/IShakeOnIt.sol";

contract UserManagement is Ownable, IShakeOnIt {
    address[] public users;
    mapping(address => bool) public isUser;
    mapping(address => address) public userStorageRegistry;
    // event to be emitted when a new user is added
    event UserAdded(address indexed user);

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
        isUser[_user] = true;
        emit UserAdded(_user);
        return address(userStorage);
    }

    /**
     * @dev Get the user storage contract address for a user
     * @param _user The address of the user
     */
    function getUserStorage(address _user) external view returns (address) {
        return userStorageRegistry[_user];
    }

    /**
     * @dev Get all registered users
     */
    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function isRegistered(address _user) external view returns (bool) {
        return isUser[_user];
    }
}
