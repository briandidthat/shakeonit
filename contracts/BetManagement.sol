// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./BetFactory.sol";
import "./UserManagement.sol";

contract BetManagement is Ownable, IShakeOnIt {
    uint256 public feesCollected;
    address[] public deployedBets;
    DataCenter private dataCenter;
    mapping(address => bool) public isBet;
    mapping(address => BetDetails) public betDetailsRegistry;

    modifier onlyBet() {
        require(isBet[msg.sender], "Restricted to bet contracts");
        _;
    }

    constructor(address _multiSig, address _dataCenter) Ownable(_multiSig) {
        dataCenter = DataCenter(_dataCenter);
    }

    /**
     * @dev Create a new bet
     * @param _betDetails The details of the bet
     */
    function createBet(BetDetails memory _betDetails) external {
        // check if the sender is the BetFactory contract, if not revert
        address factory = DataCenter(dataCenter).getBetFactory();
        require(factory == msg.sender, "Restricted to BetFactory contract");

        // get the user storage address
        address userStorageAddress = dataCenter.getUserStorage(
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
        address initiatorStorageAddress = dataCenter.getUserStorage(
            betDetails.initiator
        );
        UserStorage initiator = UserStorage(initiatorStorageAddress);
        // get the acceptor's storage address and create pointer to the user storage contract
        address acceptorStorageAddress = dataCenter.getUserStorage(_acceptor);
        UserStorage acceptor = UserStorage(acceptorStorageAddress);

        // update the state of the bet
        betDetails.acceptor = acceptorStorageAddress;
        betDetails.status = BetStatus.FUNDED;
        // save the bet for the acceptor and the initiator
        acceptor.saveBet(betDetails);
        initiator.saveBet(betDetails);
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

    /**
     * @notice Declares the winner of the bet.
     * @param _betContract The address of the bet contract
     * @param _arbiter The address of the arbiter
     * @param _winner The address of the winner
     * @param _loser The address of the loser
     */
    function declareWinner(
        address _betContract,
        address _arbiter,
        address _winner,
        address _loser,
        uint256 _platFormFee
    ) external onlyBet {
        // get the user storage address for both the winner and the loser
        address winnerStorageAddress = dataCenter.getUserStorage(_winner);
        address loserStorageAddress = dataCenter.getUserStorage(_loser);
        // get the user storage contracts
        UserStorage winnerStorage = UserStorage(winnerStorageAddress);
        UserStorage loserStorage = UserStorage(loserStorageAddress);
        // get the bet details from the winner's storage
        BetDetails memory betDetails = betDetailsRegistry[_betContract];
        // update the bet status to 'won' and set the winner
        betDetails.status = BetStatus.WON;
        betDetails.winner = _winner;
        // update the bet details in both the winner's and loser's storage
        winnerStorage.recordVictory(betDetails);
        loserStorage.recordLoss(betDetails);
        // add the platform fee to the fees collected
        feesCollected += _platFormFee;
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
        address userStorageAddress = dataCenter.getUserStorage(_initiator);
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

    function getFeesCollected() external view returns (uint256) {
        return feesCollected;
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
        return dataCenter.getUserStorage(_user);
    }

    function getMultiSig() external view returns (address) {
        return owner();
    }
}
