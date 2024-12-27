// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./DataCenter.sol";

contract UserManagement is Ownable {
    DataCenter private dataCenter;
    address[] public users;
    address[] public userStorageContracts;
    mapping(address => bool) public isUser;
    mapping(address => address) public userStorageRegistry;
    // event to be emitted when a new user is added
    event UserAdded(address indexed user, address indexed userStorage);

    modifier onlyDataCenter() {
        require(
            msg.sender == address(dataCenter),
            "Only data center can call this function"
        );
        _;
    }

    constructor(
        address _multiSigWallet,
        address _dataCenter
    ) Ownable(_multiSigWallet) {
        dataCenter = DataCenter(_dataCenter);
    }

    /**
     * @dev Add a new user
     * @param _user The address of the user
     */
    function addUser(address _user) external onlyDataCenter returns (address) {
        require(_user != address(0), "Zero address not allowed");
        require(!isUser[_user], "User already registered");
        // add the user to the list of users
        users.push(_user);
        // create a new user storage contract and store the address in the user storage registry
        UserStorage userStorage = new UserStorage(_user, address(dataCenter));
        address userStorageAddress = address(userStorage);
        userStorageRegistry[_user] = userStorageAddress;
        userStorageContracts.push(userStorageAddress);
        // set isUser to true
        isUser[_user] = true;
        // emit UserAdded event
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
