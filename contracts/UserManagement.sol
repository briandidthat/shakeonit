// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./UserStorage.sol";
import "./DataCenter.sol";
import "./Restricted.sol";

contract UserManagement is Restricted {
    address[] public users;
    address[] public userStorageContracts;
    mapping(address => bool) public isUser;
    mapping(address => UserDetails) public userDetailsRegistry;

    struct UserDetails {
        address owner;
        address storageAddress;
    }

    // event to be emitted when a new user is added
    event UserAdded(address indexed user, address indexed userStorage);

    constructor(address _multiSig) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
    }

    function register(
        string memory _username,
        address _betManagement
    ) external returns (address) {
        require(!isUser[msg.sender], "User already registered");
        // create a new user storage contract and store the address in the user storage registry
        UserStorage userStorage = new UserStorage(
            _username,
            msg.sender,
            _betManagement
        );
        address userStorageAddress = address(userStorage);
        // add the user storage contract address to the list of user storage contracts
        userStorageContracts.push(userStorageAddress);
        // add the user to the list of users
        users.push(msg.sender);
        // set isUser to true
        isUser[msg.sender] = true;
        // store the user
        userDetailsRegistry[msg.sender] = UserDetails({
            owner: msg.sender,
            storageAddress: userStorageAddress
        });
        // emit UserAdded event
        emit UserAdded(msg.sender, userStorageAddress);

        return address(userStorage);
    }

    /**
     * @dev Get the user storage contract address for a user
     * @param _user The address of the user
     */
    function getUserStorage(address _user) external view returns (address) {
        require(isUser[_user], "User not registered");
        return userDetailsRegistry[_user].storageAddress;
    }

    /**
     * @dev Get all registered users
     */
    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function getUserCount() external view returns (uint256) {
        return users.length;
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
