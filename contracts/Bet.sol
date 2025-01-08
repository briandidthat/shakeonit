// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./BetManagement.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DataCenter.sol";

contract Bet is IShakeOnIt {
    UserDetails private initiator;
    UserDetails private acceptor;
    UserDetails private arbiter;
    UserDetails private winner;
    UserDetails private loser;
    uint256 private stake;
    uint256 private arbiterFee;
    uint256 private platformFee;
    uint256 private payout;
    string private condition;
    BetStatus private status;
    BetManagement private betManagement;
    IERC20 private token;
    mapping(address => uint256) private balances;

    modifier onlyArbiter() {
        require(msg.sender == arbiter.owner, "Restricted to arbiter");
        _;
    }

    modifier onlyInitiator() {
        require(msg.sender == initiator.owner, "Restricted to initiator");
        _;
    }

    modifier onlyWinner() {
        require(msg.sender == winner.owner, "Restricted to winner");
        _;
    }

    constructor(
        address _token,
        UserDetails memory _initiator,
        UserDetails memory _arbiter,
        uint256 _stake,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _payout,
        string memory _condition
    ) {
        betManagement = BetManagement(msg.sender);
        token = IERC20(_token);
        initiator = _initiator;
        arbiter = _arbiter;
        stake = _stake;
        arbiterFee = _arbiterFee;
        platformFee = _platformFee;
        payout = _payout;
        status = BetStatus.INITIATED;
        condition = _condition;
    }

    // External functions

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(UserDetails memory _acceptor) external {
        // validate the acceptor is not the initiator or arbiter
        require(
            msg.sender != initiator.owner,
            "Initiator cannot accept the bet"
        );
        require(msg.sender != arbiter.owner, "Arbiter cannot accept the bet");
        // validate the status of the bet
        require(
            status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        require(
            balances[_acceptor.storageAddress] == 0,
            "Participant has already funded the escrow"
        );

        // update the acceptor
        acceptor = _acceptor;
        // update the status of the bet
        status = BetStatus.FUNDED;
        // update the balance of the acceptor
        balances[_acceptor.storageAddress] = stake;
        balances[arbiter.storageAddress] = arbiterFee;
        // recieve the stake from the acceptor
        require(betManagement.acceptBet(), "Bet acceptance failed");
    }

    /**
     * @notice Cancels the bet and refunds the initiator.
     * @dev This function can only be called by the initiator.
     */
    function cancelBet() external onlyInitiator {
        require(
            status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        require(
            token.transfer(initiator.storageAddress, stake),
            "Token transfer failed"
        );

        // update the balance of the initiator
        balances[initiator.storageAddress] = 0;
        status = BetStatus.CANCELLED;
        // report the cancellation to the data center
        betManagement.reportCancellation();
    }

    /**
     * @notice Declares the winner of the bet and pays the arbiter.
     * @dev This function can only be called by the arbiter.
     * @param _winner The address of the participant who is declared the winner.
     * @param _loser The address of the participant who is declared the loser.
     */
    function declareWinner(
        UserDetails memory _winner,
        UserDetails memory _loser
    ) external onlyArbiter {
        // validate the status of the bet
        require(status == BetStatus.FUNDED, "Bet has not been funded yet");
        // validate the participants
        require(
            _winner.storageAddress == initiator.storageAddress ||
                _winner.storageAddress == acceptor.storageAddress,
            "Invalid winner"
        );
        require(
            _loser.storageAddress == initiator.storageAddress ||
                _loser.storageAddress == acceptor.storageAddress,
            "Invalid loser"
        );

        // get the multiSig wallet address
        address multiSigWallet = betManagement.getMultiSig();

        // transfer the platform fee to the multisig wallet
        require(
            token.transfer(multiSigWallet, platformFee),
            "Token transfer failed"
        );
        // transfer the arbiter fee to the arbiter
        require(
            token.transfer(arbiter.storageAddress, arbiterFee),
            "Token transfer to arbiter failed"
        );
        // update the balance of the arbiter
        balances[arbiter.storageAddress] = 0;
        // assign the winner and loser
        winner = _winner;
        loser = _loser;
        // update the status of the bet
        status = BetStatus.WON;
        // report the winner to the bet management contract
        betManagement.reportWinnerDeclared();
    }

    function withdrawEarnings() external onlyWinner {
        require(status == BetStatus.WON, "Bet has not been declared won yet");
        require(balances[winner.storageAddress] > 0, "No funds to withdraw");
        // transfer the funds to the winner
        require(
            token.transfer(winner.storageAddress, payout),
            "Token transfer failed"
        );
        // update the balance of the participant
        balances[winner.storageAddress] = 0;
        // update the status of the bet
        status = BetStatus.SETTLED;
        // report the settlement to the bet management contract
        betManagement.reportBetSettled();
    }

    // Internal functions

    function _buildBetDetails() internal view returns (BetDetails memory) {
        BetDetails memory betDetails = BetDetails({
            betContract: address(this),
            token: address(token),
            initiator: initiator,
            arbiter: arbiter,
            acceptor: acceptor,
            winner: winner.storageAddress,
            loser: loser.storageAddress,
            stake: stake,
            arbiterFee: arbiterFee,
            platformFee: platformFee,
            payout: payout,
            status: status
        });
        return betDetails;
    }

    // View functions

    function getPayout() external view returns (uint256) {
        return payout;
    }

    function getArbiter() external view returns (address) {
        return arbiter.storageAddress;
    }

    function getInitiator() external view returns (address) {
        return initiator.storageAddress;
    }

    function getAcceptor() external view returns (address) {
        return acceptor.storageAddress;
    }

    function getStake() external view returns (uint256) {
        return stake;
    }

    function getWinner() external view returns (address) {
        require(status != BetStatus.INITIATED, "Bet has not been declared yet");
        return winner.owner;
    }

    function getLoser() external view returns (address) {
        require(status != BetStatus.INITIATED, "Bet has not been declared yet");
        return loser.owner;
    }

    function getAmount() external view returns (uint256) {
        return stake;
    }

    function getStatus() external view returns (BetStatus) {
        return status;
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function getArbiterFee() external view returns (uint256) {
        return arbiterFee;
    }

    function getPlatformFee() external view returns (uint256) {
        return platformFee;
    }

    function getCondition() external view returns (string memory) {
        return condition;
    }

    function getBetDetails() external view returns (BetDetails memory) {
        BetDetails memory betDetails = BetDetails({
            betContract: address(this),
            token: address(token),
            initiator: initiator,
            arbiter: arbiter,
            acceptor: acceptor,
            winner: winner.storageAddress,
            loser: loser.storageAddress,
            stake: stake,
            arbiterFee: arbiterFee,
            platformFee: platformFee,
            payout: payout,
            status: status
        });
        return betDetails;
    }
}
