// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./UserManagement.sol";

contract BetManagement is IShakeOnIt, Ownable {
    address[] public deployedBets;
    mapping(address => bool) public isBet;

    event BetCreated(
        address indexed betAddress,
        address indexed creator,
        address indexed arbiter,
        address token,
        uint256 stake,
        uint256 payout
    );

    event BetCancelled(address indexed betAddress, address indexed creator);
    event BetAccepted(address indexed betAddress, address indexed challenger);
    event BetWon(
        address indexed betAddress,
        address indexed winner,
        address indexed loser,
        uint256 arbiterFee,
        uint256 platformFee
    );
    event BetSettled(
        address indexed betAddress,
        address indexed token,
        uint256 payout
    );

    modifier isBetContract(address _betAddress) {
        require(isBet[_betAddress], "Not a valid bet contract");
        _;
    }

    constructor(address _multiSig) Ownable(_multiSig) {}

    /**
     * @notice Deploys a new bet contract and initializes it with the given parameters
     * @dev Transfers the stake from initiator to the new bet contract and updates related states
     * @param _betRequest The details of the bet including initiator, arbiter, token, stake, and other parameters
     * @custom:require The stake should be greater than 0
     * @custom:require The initiator and arbiter addresses should not be zero
     * @custom:require The initiator should have enough balance to cover the stake
     * @custom:require The initiator should have enough allowance to cover the stake
     * @custom:require The token transfer should be successful
     * @custom:emits BetCreated event with bet details
     */
    function deployBet(
        BetRequest memory _betRequest
    ) external returns (address) {
        address creator = _betRequest.creator.userContract;
        address arbiter = _betRequest.arbiter.userContract;
        address token = _betRequest.token;
        uint256 stake = _betRequest.stake;
        uint256 payout = _betRequest.payout;

        require(stake > 0, "Amount should be greater than 0");
        require(
            _betRequest.platformFee > 0,
            "Platform fee should be greater than 0"
        );
        require(
            creator != address(0) && arbiter != address(0),
            "Zero address not allowed"
        );
        require(
            IERC20(token).balanceOf(creator) >= stake,
            "Insufficient balance"
        );
        require(
            IERC20(token).allowance(creator, address(this)) >= stake,
            "Insufficient allowance"
        );

        // Deploy a new bet contract
        Bet bet = new Bet(_betRequest);
        address betAddress = address(bet);

        // transfer the stake to the bet contract
        require(
            IERC20(token).transferFrom(creator, betAddress, stake),
            "Token transfer failed"
        );

        // update balance after successful transfer
        bet.updateBalance(token, stake);

        // update the state
        isBet[betAddress] = true;
        deployedBets.push(betAddress);
        // save the bet in the initiator's and arbiter's storage
        BetDetails memory betDetails = bet.getBetDetails();
        UserStorage(creator).saveBet(betDetails);
        UserStorage(arbiter).saveBet(betDetails);
        // emit BetCreated event
        emit BetCreated(betAddress, creator, arbiter, token, stake, payout);

        return betAddress;
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(
        BetDetails memory betDetails
    ) external isBetContract(msg.sender) {
        // fund the bet contract
        require(
            IERC20(betDetails.token).transferFrom(
                betDetails.challenger,
                betDetails.betContract,
                betDetails.stake
            ),
            "Token transfer failed"
        );
        // update the bet for all parties
        UserStorage(betDetails.creator).saveBet(betDetails);
        UserStorage(betDetails.challenger).saveBet(betDetails);
        UserStorage(betDetails.arbiter).saveBet(betDetails);
        // emit BetAccepted event
        emit BetAccepted(msg.sender, betDetails.challenger);
    }

    /**
     * @notice Reports that a winner has been declared for a bet and updates storage
     * @dev Can only be called by bet contracts
     * @param betDetails The details of the bet including initiator, acceptor, arbiter, and payment info
     * @custom:events Emits BetWon event with payment details
     */
    function reportWinnerDeclared(
        BetDetails memory betDetails
    ) external isBetContract(msg.sender) {
        // update the bet for all parties
        UserStorage(betDetails.creator).saveBet(betDetails);
        UserStorage(betDetails.challenger).saveBet(betDetails);
        UserStorage(betDetails.arbiter).saveBet(betDetails);
        // emit BetWon event
        emit BetWon(
            msg.sender,
            betDetails.winner,
            betDetails.loser,
            betDetails.arbiterFee,
            betDetails.platformFee
        );
    }

    /**
     * @notice Reports that a bet has been settled and updates storage
     * @dev Can only be called by addresses with BET_CONTRACT_ROLE
     * @param betDetails The details of the bet including initiator, acceptor, arbiter, and payment info
     * @custom:events Emits BetSettled event with token and payout details
     */
    function reportBetSettled(
        BetDetails memory betDetails
    ) external isBetContract(msg.sender) {
        // update the bet for all parties
        UserStorage(betDetails.creator).saveBet(betDetails);
        UserStorage(betDetails.challenger).saveBet(betDetails);
        UserStorage(betDetails.arbiter).saveBet(betDetails);
        // set the isBet flag to false
        isBet[msg.sender] = false;
        // emit BetSettled event
        emit BetSettled(msg.sender, betDetails.token, betDetails.payout);
    }

    /**
     * @notice Cancels the bet and updates the state.
     */
    function reportCancellation(
        BetDetails memory betDetails
    ) external isBetContract(msg.sender) {
        // update the bet for initiator and arbiter (acceptor is not updated atp)
        UserStorage(betDetails.creator).saveBet(betDetails);
        UserStorage(betDetails.arbiter).saveBet(betDetails);
        // set the isBet flag to false
        isBet[msg.sender] = false;
        // emit BetCancelled event
        emit BetCancelled(msg.sender, betDetails.creator);
    }

    function setNewMultiSig(address _newMultiSig) external onlyOwner {
        _transferOwnership(_newMultiSig);
    }

    function getMultiSig() external view returns (address) {
        return owner();
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getBetCount() external view returns (uint256) {
        return deployedBets.length;
    }
}
