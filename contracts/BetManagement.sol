// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./UserManagement.sol";
import "./Restricted.sol";

contract BetManagement is IShakeOnIt, Restricted {
    address private multiSig;
    address[] public deployedBets;
    mapping(address => bool) public isBet;

    event BetCreated(
        address indexed betAddress,
        address indexed initiator,
        address indexed arbiter,
        address token,
        uint256 stake
    );

    event BetCancelled(address indexed betAddress, address indexed initiator);
    event BetAccepted(address indexed betAddress, address indexed acceptor);
    event BetWon(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        uint256 payout,
        uint256 arbiterFee,
        uint256 platformFee
    );
    event BetSettled(
        address indexed betAddress,
        address indexed token,
        uint256 payout
    );

    constructor(address _multiSig) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
        // set the multiSig address
        multiSig = _multiSig;
    }

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
        UserDetails memory initiator = _betRequest.initiator;
        UserDetails memory arbiter = _betRequest.arbiter;
        address token = _betRequest.token;
        uint256 stake = _betRequest.stake;

        require(stake > 0, "Amount should be greater than 0");
        require(
            initiator.storageAddress != address(0) &&
                arbiter.storageAddress != address(0),
            "Zero address not allowed"
        );
        require(
            IERC20(token).balanceOf(initiator.storageAddress) >= stake,
            "Insufficient balance"
        );
        require(
            IERC20(token).allowance(initiator.storageAddress, address(this)) >=
                stake,
            "Insufficient allowance"
        );

        // Deploy a new bet contract
        Bet bet = new Bet(
            token,
            initiator,
            arbiter,
            stake,
            _betRequest.arbiterFee,
            _betRequest.platformFee,
            _betRequest.payout,
            _betRequest.condition
        );
        address betAddress = address(bet);

        // transfer the stake to the bet contract
        require(
            IERC20(token).transferFrom(
                initiator.storageAddress,
                betAddress,
                stake
            ),
            "Token transfer failed"
        );

        // update balance after successful transfer
        bet.updateBalance(token, stake);

        // update the state
        isBet[betAddress] = true;
        deployedBets.push(betAddress);
        // grant the bet contract the BET_CONTRACT_ROLE
        _grantRole(BET_CONTRACT_ROLE, betAddress);
        // save the bet in the initiator's and arbiter's storage
        BetDetails memory betDetails = bet.getBetDetails();
        UserStorage(initiator.storageAddress).saveBet(betDetails);
        UserStorage(arbiter.storageAddress).saveBet(betDetails);
        // emit BetCreated event
        emit BetCreated(
            betAddress,
            initiator.storageAddress,
            arbiter.storageAddress,
            token,
            stake
        );

        return betAddress;
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(
        BetDetails memory betDetails
    ) external hasCorrectRole(BET_CONTRACT_ROLE) {
        // fund the bet contract
        require(
            IERC20(betDetails.token).transferFrom(
                betDetails.acceptor.storageAddress,
                betDetails.betContract,
                betDetails.stake
            ),
            "Token transfer failed"
        );
        // update the bet for all parties
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.acceptor.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // emit BetAccepted event
        emit BetAccepted(msg.sender, betDetails.acceptor.storageAddress);
    }

    /**
     * @notice Reports that a winner has been declared for a bet and updates storage
     * @dev Can only be called by addresses with BET_CONTRACT_ROLE
     * @param betDetails The details of the bet including initiator, acceptor, arbiter, and payment info
     * @custom:events Emits BetWon event with payment details
     */
    function reportWinnerDeclared(
        BetDetails memory betDetails
    ) external hasCorrectRole(BET_CONTRACT_ROLE) {
        // update the bet for all parties
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.acceptor.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // emit BetWon event
        emit BetWon(
            msg.sender,
            betDetails.winner,
            betDetails.arbiter.storageAddress,
            betDetails.payout,
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
    ) external hasCorrectRole(BET_CONTRACT_ROLE) {
        // update the bet for all parties
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.acceptor.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);

        // remove the BET_CONTRACT_ROLE from the bet contract
        _revokeRole(BET_CONTRACT_ROLE, msg.sender);
        // emit BetSettled event
        emit BetSettled(msg.sender, betDetails.token, betDetails.payout);
    }

    /**
     * @notice Cancels the bet and updates the state.
     */
    function reportCancellation(
        BetDetails memory betDetails
    ) external hasCorrectRole(BET_CONTRACT_ROLE) {
        // update the bet for initiator and arbiter (acceptor is not updated atp)
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // remove the BET_CONTRACT_ROLE from the bet contract
        _revokeRole(BET_CONTRACT_ROLE, msg.sender);
        // emit BetCancelled event
        emit BetCancelled(msg.sender, betDetails.initiator.storageAddress);
    }

    function setNewMultiSig(
        address _newMultiSig
    ) external onlyRole(MULTISIG_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, _newMultiSig);
        _grantRole(MULTISIG_ROLE, _newMultiSig);
        _revokeRole(MULTISIG_ROLE, msg.sender);

        multiSig = _newMultiSig;
    }

    function getMultiSig() external view returns (address) {
        return multiSig;
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getBetCount() external view returns (uint256) {
        return deployedBets.length;
    }
}
