// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./UserStorage.sol";
import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UserManagement is IShakeOnIt, Ownable {
    address[] public users;
    address[] public userStorageContracts;
    mapping(address => bool) public isUser;
    mapping(address => User) public userRegistry;

    // event to be emitted when a new user is added
    event UserAdded(
        address indexed user,
        address indexed userStorage,
        bytes32 username
    );

    constructor(address _multiSig) Ownable(_multiSig) {}

    function register(
        bytes32 _username,
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
        userRegistry[msg.sender] = User({
            signer: msg.sender,
            username: _username,
            userContract: userStorageAddress
        });
        // emit UserAdded event
        emit UserAdded(msg.sender, userStorageAddress, _username);

        return address(userStorage);
    }

    function setNewMultiSig(address _newMultiSig) external onlyOwner {
        _transferOwnership(_newMultiSig);
    }

    function getMultiSig() external view returns (address) {
        return owner();
    }

    function getUser(address _user) external view returns (User memory) {
        require(isUser[_user], "User not registered");
        return userRegistry[_user];
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
