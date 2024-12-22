// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./Arbiter.sol";
import "./interfaces/IShakeOnIt.sol";

contract DataCenter is IShakeOnIt, Ownable {
    address[] private deployedBets;
    address[] private users;
    address[] private arbiters;
    address[] private blockedArbiters;
    mapping(address => bool) private isBet;
    mapping(address => bool) private isUser;
    mapping(address => bool) private isArbiter;
    mapping(address => address) private userStorageRegistry;
    mapping(address => address) private arbiterRegistry;

    constructor(address _factory) Ownable(_factory) {}

    function createBet(BetDetails memory _betDetails) external onlyOwner {
        address userStorageAddress = userStorageRegistry[_betDetails.initiator];
        // if the user doesn't have a storage contract, throw an error
        require(userStorageAddress != address(0), "User not registered");
        UserStorage userStorage = UserStorage(userStorageAddress);
        // store the new bet in the user storage
        userStorage.saveBet(_betDetails);
        // add the bet to the list of deployed bets
        deployedBets.push(_betDetails.betContract);
        // add the bet to isBet mapping
        isBet[_betDetails.betContract] = true;
        // emit BetCreated event
        emit BetCreated(
            _betDetails.betContract,
            _betDetails.initiator,
            _betDetails.arbiter,
            _betDetails.fundToken,
            _betDetails.amount,
            _betDetails.deadline
        );
    }

    function acceptBet(BetDetails memory _betDetails) external {
        require(
            isBet[msg.sender],
            "Only a bet contract can call this function"
        );
        // get the user storage contract address for both the initiator and the acceptor
        address acceptorStorage = userStorageRegistry[_betDetails.acceptor];
        address initiatorStorage = userStorageRegistry[_betDetails.initiator];
        // save the bet for the acceptor
        UserStorage(acceptorStorage).saveBet(_betDetails);
        // update the bet status for the initiator
        UserStorage(initiatorStorage).updateBet(_betDetails);
        // emit BetAccepted event
        emit BetAccepted(
            _betDetails.betContract,
            _betDetails.acceptor,
            _betDetails.fundToken,
            _betDetails.amount,
            _betDetails.deadline
        );
    }

    function declareWinner(
        address _betContract,
        address _arbiter,
        address _winner,
        address _loser
    ) external {
        require(isBet[_betContract], "Bet not found");
        require(isArbiter[_arbiter], "Arbiter not found");
        // get the user storage address for both the winner and the loser
        address winnerStorageAddress = userStorageRegistry[_arbiter];
        address loserStorageAddress = userStorageRegistry[_loser];
        // get the user storage contracts
        UserStorage winnerStorage = UserStorage(winnerStorageAddress);
        UserStorage loserStorage = UserStorage(loserStorageAddress);
        // get the bet details from the winner's storage
        BetDetails memory betDetails = winnerStorage.getBetDetails(
            _betContract
        );
        require(betDetails.status == BetStatus.FUNDED, "Bet not funded");
        // update the bet status to 'won' and set the winner
        betDetails.status = BetStatus.WON;
        betDetails.winner = _winner;
        // update the bet details in both the winner's and loser's storage
        winnerStorage.updateBet(betDetails);
        loserStorage.updateBet(betDetails);
        // emit BetWon event
        emit BetWon(
            _betContract,
            _winner,
            _arbiter,
            betDetails.fundToken,
            betDetails.amount
        );
    }

    function cancelBet(address _betContract, address _initiator) external {
        address userStorageAddress = userStorageRegistry[_initiator];
        UserStorage userStorage = UserStorage(userStorageAddress);
        // get the bet details from the user storage
        BetDetails memory betDetails = userStorage.getBetDetails(_betContract);
        require(betDetails.initiator == _initiator, "Restricted to initiator");
        require(betDetails.status != BetStatus.FUNDED, "Bet already funded");
        // update the bet status in the user storage. We do not need to do this
        // for the acceptor since the bet is not funded yet, so no acceptor exists
        userStorage.cancelBet(_betContract);
        // emit BetCancelled event
        emit BetCancelled(_betContract, msg.sender);
    }

    function addUser(address _user) external onlyOwner returns (address) {
        require(!isUser[_user], "User already registered");
        // create a new user storage contract
        UserStorage userStorage = new UserStorage(_user, address(this));
        address userStorageAddress = address(userStorage);
        // store the user storage contract address and add the user to the list of users
        userStorageRegistry[_user] = userStorageAddress;
        users.push(_user);
        isUser[_user] = true;
        // emit UserAdded event
        emit UserAdded(_user, userStorageAddress);
        // return the user storage contract address
        return userStorageAddress;
    }

    function blockArbiter(
        address _arbiter,
        string memory _reason
    ) external onlyOwner {
        require(isArbiter[_arbiter], "Arbiter not found");

        address arbiterContractAddress = arbiterRegistry[_arbiter];
        Arbiter arbiter = Arbiter(arbiterContractAddress);
        arbiter.setArbiterStatus(ArbiterStatus.BLOCKED);
        // emit ArbiterBlocked event
        emit ArbiterBlocked(_arbiter, _reason);
    }

    function addArbiter(address _arbiter) external onlyOwner {
        require(_arbiter != address(0), "Zero address not allowed");
        require(!isArbiter[_arbiter], "Arbiter already added");
        // add the arbiter
        arbiters.push(_arbiter);
    }

    function setNewFactory(address _newFactory) external onlyOwner {
        require(_newFactory != address(0), "Zero address not allowed");
        require(_newFactory != owner(), "Owner cannot be the new factory");
        // transfer ownership to the new factory
        _transferOwnership(_newFactory);
    }

    function getUserStorage(address _user) external view returns (address) {
        require(isUser[msg.sender], "User has not registered");
        return userStorageRegistry[_user];
    }

    function getArbiter(address _arbiter) external view returns (address) {
        require(isArbiter[msg.sender], "Arbiter not found");
        return arbiterRegistry[_arbiter];
    }

    function getUsers() external view returns (address[] memory) {
        return users;
    }

    function getArbiters() external view returns (address[] memory) {
        return arbiters;
    }

    function getBlockedArbiters() external view returns (address[] memory) {
        return blockedArbiters;
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }
}
