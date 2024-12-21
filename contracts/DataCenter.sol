// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./interfaces/IShakeOnIt.sol";

contract DataCenter is IShakeOnIt, Ownable {
    uint256 private platformPercentage;
    address[] private deployedBets;
    address[] private users;
    address[] private arbiters;
    address[] private blockedArbiters;
    mapping(address => bool) private isBet;
    mapping(address => bool) private isUser;
    mapping(address => bool) private isArbiter;
    mapping(address => bool) private isArbiterBlocked;
    mapping(address => address) private userStorageRegistry;
    mapping(address => address) private arbiterRegistry;

    constructor(address _factory) Ownable(_factory) {}

    /**
     * @notice Saves a new bet to the user's storage contract
     * @dev Creates a new UserStorage contract if user doesn't have one yet
     * @param _betContract Address of the bet contract
     * @param _initiator Address of the user initiating the bet
     * @param _arbiter Address of the arbiter for this bet
     * @param _fundToken Address of the token used for betting
     * @param _amount Amount of tokens to be bet
     * @param _deadline Timestamp when the bet expires
     * @param _message Description or terms of the bet
     * @custom:access Only owner
     */
    function createBet(
        address _betContract,
        address _initiator,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _message
    ) external onlyOwner {
        address userStorageAddress = userStorageRegistry[_initiator];
        UserStorage userStorage;
        // create a new user storage contract if the user doesn't have one yet
        if (userStorageAddress == address(0)) {
            userStorage = new UserStorage(_initiator, address(this));
            userStorageAddress = address(userStorage);
            userStorageRegistry[_initiator] = userStorageAddress;
            users.push(_initiator);
            isUser[_initiator] = true;
        } else {
            userStorage = UserStorage(userStorageAddress);
        }
        // store the new bet in the user storage
        userStorage.saveBet(
            _betContract,
            _arbiter,
            _fundToken,
            _amount,
            _deadline,
            _message
        );
        // add the bet to the list of deployed bets
        deployedBets.push(_betContract);
        // add the bet to bet mapping
        isBet[_betContract] = true;
        // emit BetCreated event
        emit BetCreated(
            _betContract,
            _initiator,
            _arbiter,
            _fundToken,
            _amount,
            _deadline
        );
    }

    /**
     * @notice Updates the bet details in the user storage contract
     * @param _betDetails The BetDetails details to be updated
     * @custom:access Only a bet contract
     */
    function updateBet(BetDetails memory _betDetails) external {
        require(
            isBet[_betDetails.betContract],
            "Only a bet contract can call this function"
        );

        // get the user storage contract address for both the initiator and the acceptor
        address initiatorStorage = userStorageRegistry[_betDetails.initiator];
        address acceptorStorage = userStorageRegistry[_betDetails.acceptor];
        // update the bet in the user storage for both the initiator and the acceptor
        UserStorage(initiatorStorage).updateBet(_betDetails);
        UserStorage(acceptorStorage).updateBet(_betDetails);

        // emit BetUpdated event
        emit BetUpdated(_betDetails);
    }

    /**
     * @notice This function is called when a bet is accepted.
     * @param _betDetails The BetDetails details including proposer and acceptor addresses.
     * @dev Updates the bet status in the user storage contract and registers the acceptor if they are a new user.
     */
    function betAccepted(BetDetails memory _betDetails) external {
        require(
            isBet[msg.sender],
            "Only a bet contract can call this function"
        );
        address acceptorStorage;
        address acceptor = _betDetails.acceptor;
        address initiatorStorage = userStorageRegistry[_betDetails.initiator];

        // if the acceptor is a new user, add them to the user list and marks them as a user.
        if (!isUser[_betDetails.acceptor]) {
            /// @dev Create a new user storage contract for the acceptor
            UserStorage newStorage = new UserStorage(acceptor, address(this));
            acceptorStorage = address(newStorage);
            userStorageRegistry[acceptor] = acceptorStorage;
            users.push(acceptor);
            isUser[acceptor] = true;
        } else {
            // get the user storage contract address
            acceptorStorage = userStorageRegistry[_betDetails.acceptor];
        }

        // update the bet status for both the initiator and the acceptor
        UserStorage(initiatorStorage).updateBet(_betDetails);
        UserStorage(acceptorStorage).updateBet(_betDetails);

        // emit BetAccepted event
        emit BetAccepted(
            _betDetails.betContract,
            _betDetails.acceptor,
            _betDetails.fundToken,
            _betDetails.amount,
            _betDetails.deadline
        );
    }

    /**
     * @notice This function is called when a bet is cancelled.
     * @param _betContract The address of the bet contract.
     * @dev Updates the bet status in the user storage contract.
     */
    function cancelBet(address _betContract, address _initiator) external {
        address userStorageAddress = userStorageRegistry[_initiator];
        UserStorage userStorage = UserStorage(userStorageAddress);

        BetDetails memory betDetails = userStorage.getBetDetails(_betContract);
        require(betDetails.initiator == _initiator, "Restricted to initiator");

        // update the bet status in the user storage
        userStorage.cancelBet(_betContract);
        emit BetCancelled(_betContract, msg.sender);
    }

    /**
     * @dev Block an arbiter
     * @param _arbiter The address of the arbiter to be blocked
     */
    function blockArbiter(
        address _arbiter,
        string memory _reason
    ) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiterBlocked[_arbiter], "Arbiter already blocked");
        // block the specified arbiter
        blockedArbiters.push(_arbiter);
        isArbiterBlocked[_arbiter] = true;
        // emit ArbiterBlocked event
        emit ArbiterBlocked(_arbiter, _reason);
    }

    /**
     * @dev Add an arbiter
     * @param _arbiter The address of the arbiter to be added
     */
    function addArbiter(address _arbiter) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiter[_arbiter], "Arbiter already added");
        require(!isArbiterBlocked[_arbiter], "Arbiter was blocked previously");
        // add the arbiter
        arbiters.push(_arbiter);
    }

    /**
     * @dev Get user storage address
     * @param _user The address of the user
     */
    function getUserStorage(address _user) external view returns (address) {
        require(isUser[msg.sender], "User has not created any bet");
        return userStorageRegistry[_user];
    }

    /**
     * @dev Get arbiter contract address
     * @param _arbiter The address of the arbiter
     */
    function getArbiter(address _arbiter) external view returns (address) {
        require(isArbiter[msg.sender], "Arbiter not found");
        return arbiterRegistry[_arbiter];
    }

    /**
     * @dev Get the list of all users
     */
    function getUsers() external view returns (address[] memory) {
        return users;
    }

    /**
     * @dev Get the list of all arbiters
     */
    function getArbiters() external view returns (address[] memory) {
        return arbiters;
    }

    /**
     * @dev Get the list of all blocked arbiters
     */
    function getBlockedArbiters() external view returns (address[] memory) {
        return blockedArbiters;
    }

    /**
     * @dev Get the list of all bets
     */
    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    /**
     * @notice Sets a new factory address and transfers ownership to the new factory.
     * @dev This function can only be called by the current owner.
     * @param _newFactory The address of the new factory to be set.
     */
    function setNewFactory(address _newFactory) external onlyOwner {
        require(_newFactory != address(0), "Zero address not allowed");
        require(_newFactory != owner(), "Owner cannot be the new factory");
        // transfer ownership to the new factory
        _transferOwnership(_newFactory);
    }

    /**
     * @notice Sets the platform percentage, represented in basis points.
     * @dev This function can only be called by the current owner.
     * @param _platformPercentage The new platform percentage to be set.
     */
    function setPlatformPercentage(
        uint256 _platformPercentage
    ) external onlyOwner {
        platformPercentage = _platformPercentage;
    }

    /**
     * @notice Gets the platform percentage represented in basis points.
     */
    function getPlatformPercentage() external view returns (uint256) {
        return platformPercentage;
    }

    /**
     * @dev Get the details of a bet
     * @param _betContract The address of the bet contract
     * @param _user The address of the user
     */
    function getBetDetails(
        address _betContract,
        address _user
    ) external view returns (BetDetails memory) {
        address userStorageAddress = userStorageRegistry[_user];
        UserStorage userStorage = UserStorage(userStorageAddress);
        BetDetails memory betDetails = userStorage.getBetDetails(_betContract);
        return betDetails;
    }
}
