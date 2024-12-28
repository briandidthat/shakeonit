// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./UserStorage.sol";
import "./DataCenter.sol";
import "./Restricted.sol";

contract UserManagement is Restricted {
    bool private initialized;
    address[] public users;
    address[] public userStorageContracts;
    mapping(address => bool) public isUser;
    mapping(address => address) public userStorageRegistry;
    // event to be emitted when a new user is added
    event UserAdded(address indexed user, address indexed userStorage);

    modifier isInitialized() {
        require(initialized, "Contract not initialized");
        _;
    }

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
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _initializeRoles(contracts);
        initialized = true;
    }

    /**
     * @dev Add a new user
     * @param _user The address of the user
     */
    function register(
        address _user,
        Requestor[] calldata contracts
    ) external isInitialized returns (address) {
        require(_user != address(0), "Zero address not allowed");
        require(!isUser[_user], "User already registered");
        // add the user to the list of users
        users.push(_user);
        // create a new user storage contract and store the address in the user storage registry
        UserStorage userStorage = new UserStorage(_user, contracts);
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
