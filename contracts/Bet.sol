// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./BetManagement.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DataCenter.sol";

contract Bet is IShakeOnIt {
    string private condition;
    BetDetails private betDetails;
    BetManagement private betManagement;
    IERC20 private token;
    mapping(address => uint256) private balances;

    modifier onlyArbiter(address _arbiter) {
        require(_arbiter == betDetails.arbiter, "Restricted to arbiter");
        _;
    }

    modifier onlyWinner() {
        require(msg.sender == betDetails.winner, "Restricted to winner");
        _;
    }

    modifier isParticipant(address _participant1, address _participant2) {
        require(
            _participant1 == betDetails.initiator ||
                _participant1 == betDetails.acceptor,
            "Restricted to participant"
        );
        require(
            _participant2 == betDetails.initiator ||
                _participant2 == betDetails.acceptor,
            "Restricted to participant"
        );
        _;
    }

    constructor(
        address _betManagement,
        address _token,
        address _initiator,
        address _arbiter,
        uint256 _stake,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _payout,
        string memory _condition
    ) {
        betManagement = BetManagement(_betManagement);
        token = IERC20(_token);
        condition = _condition;
        // set the bet details
        betDetails = BetDetails({
            betContract: address(this),
            token: _token,
            initiator: _initiator,
            arbiter: _arbiter,
            acceptor: address(0),
            winner: address(0),
            loser: address(0),
            stake: _stake,
            arbiterFee: _arbiterFee,
            platformFee: _platformFee,
            payout: _payout,
            status: BetStatus.INITIATED
        });
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(address _acceptor) external {
        require(
            betDetails.status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        require(
            balances[_acceptor] == 0,
            "Participant has already funded the escrow"
        );
        require(
            token.transferFrom(_acceptor, address(this), betDetails.stake),
            "Token transfer failed"
        );

        // update the bet details
        betDetails.acceptor = _acceptor;
        betDetails.status = BetStatus.FUNDED;
        // update the balance of the acceptor
        balances[_acceptor] = betDetails.stake;
        balances[betDetails.arbiter] = betDetails.arbiterFee;
        // report the acceptance to the bet management contract
        betManagement.reportAcceptance(betDetails);
    }

    /**
     * @notice Cancels the bet and refunds the initiator.
     * @dev This function can only be called by the initiator.
     */
    function cancelBet(address _initiator) external {
        require(_initiator == betDetails.initiator, "Restricted to initiator");
        require(
            betDetails.status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        require(
            token.transfer(_initiator, betDetails.stake),
            "Token transfer failed"
        );

        // update the balance of the initiator
        balances[betDetails.initiator] = 0;
        betDetails.status = BetStatus.CANCELLED;
        betDetails.winner = address(0);
        betDetails.loser = address(0);
        // report the cancellation to the data center
        betManagement.reportCancellation(betDetails);
    }

    /**
     * @notice Declares the winner of the bet and pays the arbiter.
     * @dev This function can only be called by the arbiter.
     * @param _winner The address of the participant who is declared the winner.
     */
    function declareWinner(
        address _dataCenter,
        address _arbiter,
        address _winner,
        address _loser
    )
        external
        onlyArbiter(_arbiter)
        isParticipant(_winner, _loser)
        returns (uint256)
    {
        require(
            betDetails.status == BetStatus.FUNDED,
            "Bet has not been funded yet"
        ); // ensure the bet is funded

        // get the multisig wallet address for the platform fee
        address multiSigWallet = DataCenter(_dataCenter).getMultiSig();

        // transfer the platform fee to the multisig wallet
        require(
            token.transfer(multiSigWallet, betDetails.platformFee),
            "Token transfer failed"
        );

        // update the winner and loser
        betDetails.winner = _winner;
        betDetails.loser = _loser;
        // update the status of the bet
        betDetails.status = BetStatus.WON;
        require(
            token.transfer(betDetails.arbiter, betDetails.arbiterFee),
            "Token transfer to arbiter failed"
        );
        // update the balance of the arbiter
        balances[betDetails.arbiter] = 0;

        // update the bet details
        betDetails.winner = _winner;
        betDetails.loser = _loser;
        betDetails.status = BetStatus.WON;
        // report the winner to the bet management contract
        betManagement.reportWinnerDeclared(betDetails);
        return betDetails.arbiterFee;
    }

    function withdrawEarnings(address _winner) external onlyWinner {
        require(
            betDetails.status == BetStatus.WON,
            "Bet has not been declared won yet"
        );
        require(balances[_winner] > 0, "No funds to withdraw");
        // transfer the funds to the winner
        require(
            token.transfer(_winner, betDetails.payout),
            "Token transfer failed"
        );
        // update the balance of the participant
        balances[_winner] = 0;
        // update the status of the bet
        betDetails.status = BetStatus.SETTLED;
        // report the settlement to the bet management contract
        betManagement.reportBetSettled(betDetails);
    }

    function getPayout() external view returns (uint256) {
        return betDetails.payout;
    }

    function getBetDetails() external view returns (BetDetails memory) {
        return betDetails;
    }

    function getArbiter() external view returns (address) {
        return betDetails.arbiter;
    }

    function getInitiator() external view returns (address) {
        return betDetails.initiator;
    }

    function getAcceptor() external view returns (address) {
        return betDetails.acceptor;
    }

    function getWinner() external view returns (address) {
        require(
            betDetails.status != BetStatus.INITIATED,
            "Bet has not been declared yet"
        );
        return betDetails.winner;
    }

    function getStake() external view returns (uint256) {
        return betDetails.stake;
    }

    function getLoser() external view returns (address) {
        require(
            betDetails.status != BetStatus.INITIATED,
            "Bet has not been declared yet"
        );
        return betDetails.loser;
    }

    function getAmount() external view returns (uint256) {
        return betDetails.stake;
    }

    function getStatus() external view returns (BetStatus) {
        return betDetails.status;
    }

    function getToken() external view returns (address) {
        return betDetails.token;
    }

    function getArbiterFee() external view returns (uint256) {
        return betDetails.arbiterFee;
    }

    function getPlatformFee() external view returns (uint256) {
        return betDetails.platformFee;
    }

    function getCondition() external view returns (string memory) {
        return condition;
    }
}
