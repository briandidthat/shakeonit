// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./BetFactory.sol";
import "./UserManagement.sol";

contract BetManagement is Ownable, IShakeOnIt {
    uint256 public feesCollected;
    address[] public deployedBets;
    address public betFactory;
    UserManagement public userManagement;
    mapping(address => bool) public isBet;
    mapping(address => BetDetails) public betDetailsRegistry;

    modifier onlyBet() {
        require(isBet[msg.sender], "Restricted to bet contracts");
        _;
    }

    modifier onlyBetFactory() {
        require(msg.sender == betFactory, "Restricted to bet factory");
        _;
    }

    constructor(address _multiSig, address _betFactory) Ownable(_multiSig) {
        betFactory = _betFactory;
    }

    /**
     * @dev Create a new bet
     * @param _betDetails The details of the bet
     */
    function createBet(BetDetails memory _betDetails) external onlyBetFactory {
        // get the user storage address
        address userStorageAddress = userManagement.getUserStorage(
            _betDetails.initiator
        );
        // create pointer to the user storage contract
        UserStorage userStorage = UserStorage(userStorageAddress);
        // transfer the amount to the bet contract
        require(
            IERC20(_betDetails.fundToken).transferFrom(
                userStorageAddress,
                _betDetails.betContract,
                _betDetails.amount
            ),
            "Token transfer failed"
        );

        // update the state and create the bet in user storage
        deployedBets.push(_betDetails.betContract);
        isBet[_betDetails.betContract] = true;
        // save the bet for the initiator
        userStorage.saveBet(_betDetails);
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

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(address _acceptor) external onlyBet {
        // get the bet details
        BetDetails storage betDetails = betDetailsRegistry[msg.sender];
        // get the initiator's storage address and create pointer to the user storage contract
        address initiatorStorageAddress = userManagement.getUserStorage(
            betDetails.initiator
        );
        UserStorage initiator = UserStorage(initiatorStorageAddress);
        // get the acceptor's storage address and create pointer to the user storage contract
        address acceptorStorageAddress = userManagement.getUserStorage(
            _acceptor
        );
        UserStorage acceptor = UserStorage(acceptorStorageAddress);

        // update the state of the bet
        betDetails.accepted = true;
        betDetails.acceptor = acceptorStorageAddress;
        betDetails.status = BetStatus.FUNDED;
        // save the bet for the acceptor
        acceptor.saveBet(betDetails);
        // update the bet for the initiator
        initiator.updateBet(betDetails);
        // ujpdate the bet details registry
        betDetailsRegistry[msg.sender] = betDetails;

        // emit BetAccepted event
        emit BetAccepted(
            betDetails.betContract,
            betDetails.acceptor,
            betDetails.fundToken,
            betDetails.amount,
            betDetails.deadline
        );
    }

    function declareWinner(
        address _betContract,
        address _arbiter,
        address _winner,
        address _loser
    ) external onlyBet {
        // get the user storage address for both the winner and the loser
        address winnerStorageAddress = userManagement.getUserStorage(_winner);
        address loserStorageAddress = userManagement.getUserStorage(_loser);
        // get the user storage contracts
        UserStorage winnerStorage = UserStorage(winnerStorageAddress);
        UserStorage loserStorage = UserStorage(loserStorageAddress);
        // get the bet details from the winner's storage
        BetDetails memory betDetails = betDetailsRegistry[_betContract];
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

    /**
     * @notice Cancels the bet and updates the state.
     */
    function cancelBet(address _initiator) external onlyBet {
        // get the user storage address
        address userStorageAddress = userManagement.getUserStorage(_initiator);
        UserStorage userStorage = UserStorage(userStorageAddress);
        // cancel the bet
        userStorage.cancelBet(msg.sender);
        // update the state and update the bet details registry
        BetDetails memory betDetails = betDetailsRegistry[msg.sender];
        betDetails.status = BetStatus.CANCELLED;
        betDetailsRegistry[msg.sender] = betDetails;
        // emit BetCancelled event
        emit BetCancelled(msg.sender, _initiator);
    }

    function reportFeesCollected(uint256 _fees) external onlyBet {
        feesCollected += _fees;
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getBetDetails(
        address _betContract
    ) external view returns (BetDetails memory) {
        return betDetailsRegistry[_betContract];
    }

    function getUserStorage(address _user) external view returns (address) {
        return userManagement.getUserStorage(_user);
    }

    function getMultiSig() external view returns (address) {
        return owner();
    }
}
