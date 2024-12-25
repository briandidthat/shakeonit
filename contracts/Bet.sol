// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./BetManagement.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bet is IShakeOnIt {
    address private initiator;
    address private acceptor;
    address private arbiter;
    address private winner;
    address private loser;
    uint256 private amount;
    uint256 private payout;
    uint256 private arbiterFee;
    uint256 private platformFee;
    uint256 private deadline;
    string private condition;
    BetManagement private betManagement;
    IERC20 private fundToken;
    BetStatus private status;
    mapping(address => uint256) private balances;

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Restricted to arbiter");
        _;
    }

    modifier onlyWinner() {
        require(msg.sender == winner, "Restricted to winner");
        _;
    }

    constructor(
        address _betManagement,
        address _fundToken,
        address _initiator,
        address _arbiter,
        uint256 _amount,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _payout,
        uint256 _deadline,
        string memory _condition
    ) {
        betManagement = BetManagement(_betManagement);
        fundToken = IERC20(_fundToken);
        initiator = _initiator;
        arbiter = _arbiter;
        amount = _amount;
        arbiterFee = _arbiterFee;
        platformFee = _platformFee;
        payout = _payout;
        deadline = _deadline;
        condition = _condition;
        status = BetStatus.INITIATED;
        // temp values
        acceptor = address(0);
        winner = address(0);
        loser = address(0);
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet() external {
        require(
            status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        // get the user storage address and perform the token transfer
        address userStorageAddress = betManagement.getUserStorage(msg.sender);
        require(userStorageAddress != address(0), "User has not registered");
        require(
            balances[userStorageAddress] == 0,
            "Participant has already funded the escrow"
        );
        require(
            fundToken.transferFrom(userStorageAddress, address(this), amount),
            "Token transfer failed"
        );

        // update the balance of the acceptor and contract state
        acceptor = userStorageAddress;
        balances[userStorageAddress] = amount;
        status = BetStatus.FUNDED;
        // report the acceptance to the bet management contract
        betManagement.acceptBet(msg.sender);
    }

    /**
     * @notice Cancels the bet and refunds the initiator.
     * @dev This function can only be called by the initiator.
     */
    function cancelBet() external {
        address userStorageAddress = betManagement.getUserStorage(msg.sender);
        require(userStorageAddress == initiator, "Restricted to initiator");
        require(
            status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        require(acceptor == address(0), "Bet has been already been accepted");
        require(
            fundToken.transfer(userStorageAddress, amount),
            "Token transfer failed"
        );

        // update the balance of the initiator
        balances[initiator] = 0;
        status = BetStatus.CANCELLED;
        // report the cancellation to the data center
        betManagement.cancelBet(initiator);
    }

    /**
     * @notice Declares the winner of the bet and pays the arbiter.
     * @dev This function can only be called by the arbiter.
     * @param _winner The address of the participant who is declared the winner.
     */
    function declareWinner(
        address _winner,
        address _loser
    ) external onlyArbiter {
        require(_winner == initiator || _winner == acceptor, "Invalid winner"); // ensure the winner is a participant
        require(_loser == initiator || _loser == acceptor, "Invalid winner"); // ensure the loser is a participant
        require(status == BetStatus.FUNDED, "Bet has not been funded yet"); // ensure the bet is funded
        require(block.timestamp >= deadline, "Deadline has not passed yet"); // ensure the deadline has passed

        // update the winner and loser
        winner = _winner;
        loser = _loser;
        // update the status of the bet
        status = BetStatus.WON;
        require(
            fundToken.transfer(arbiter, arbiterFee),
            "Token transfer to arbiter failed"
        );
        // update the balance of the arbiter
        balances[msg.sender] = 0;
        // get the multisig wallet address for the platform fee
        address multiSigWallet = betManagement.getMultiSig();
        // transfer the platform fee to the multisig wallet
        require(
            fundToken.transfer(multiSigWallet, platformFee),
            "Token transfer failed"
        );
        // report the winner to the bet management contract
        betManagement.declareWinner(
            address(this),
            arbiter,
            _winner,
            _loser,
            platformFee
        );
    }

    function withdrawEarnings() external onlyWinner {
        require(status == BetStatus.WON, "Bet has not been declared won yet");
        // get the user storage address
        address userStorageAddress = betManagement.getUserStorage(msg.sender);
        require(userStorageAddress == winner, "Restricted to winner");
        require(balances[userStorageAddress] > 0, "No funds to withdraw");
        // transfer the funds to the winner
        require(
            fundToken.transfer(userStorageAddress, payout),
            "Token transfer failed"
        );
        // update the balance of the participant
        balances[userStorageAddress] = 0;
        // update the status of the bet
        status = BetStatus.SETTLED;
    }

    function getArbiter() external view returns (address) {
        return arbiter;
    }

    function getInitiator() external view returns (address) {
        return initiator;
    }

    function getAcceptor() external view returns (address) {
        return acceptor;
    }

    function getWinner() external view returns (address) {
        return winner;
    }

    function getLoser() external view returns (address) {
        return loser;
    }

    function getAmount() external view returns (uint256) {
        return amount;
    }

    function getStatus() external view returns (BetStatus) {
        return status;
    }

    function getFundToken() external view returns (address) {
        return address(fundToken);
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
}
