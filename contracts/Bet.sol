// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./BetManagement.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Bet is IShakeOnIt, Initializable {
    address private initiator;
    address private acceptor;
    address private arbiter;
    address private winner;
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

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _betManagement,
        address _fundToken,
        address _initiator,
        address _arbiter,
        uint256 _amount,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _deadline,
        string memory _condition
    ) external initializer {
        betManagement = BetManagement(_betManagement);
        fundToken = IERC20(_fundToken);
        initiator = _initiator;
        arbiter = _arbiter;
        amount = _amount;
        arbiterFee = _arbiterFee;
        platformFee = _platformFee;
        payout = amount - (arbiterFee + platformFee);
        deadline = _deadline;
        condition = _condition;
        status = BetStatus.INITIATED;
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
     * @return _arbiterFee amount paid to the arbiter.
     */
    function declareWinner(
        address _winner,
        address _loser
    ) external onlyArbiter returns (uint256 _arbiterFee) {
        require(_winner == initiator || _winner == acceptor, "Invalid winner"); // ensure the winner is a participant
        require(status == BetStatus.FUNDED, "Bet has not been funded yet"); // ensure the bet is funded
        require(block.timestamp >= deadline, "Deadline has not passed yet"); // ensure the deadline has passed

        // update the winner
        winner = _winner;
        // update the status of the bet
        status = BetStatus.WON;
        require(
            fundToken.transfer(arbiter, arbiterFee),
            "Token transfer to arbiter failed"
        );
        // update the balance of the arbiter
        balances[msg.sender] = 0;
        // report the winner to the bet management contract
        betManagement.declareWinner(address(this), arbiter, _winner, _loser);

        // emit BetWon event
        emit BetWon(address(this), winner, arbiter, address(fundToken), amount);
        // return the arbiter fee
        _arbiterFee = arbiterFee;
    }

    function withdrawEarnings() external onlyWinner {
        require(status == BetStatus.WON, "Bet has not been declared won yet");
        // get the user storage address
        address userStorageAddress = betManagement.getUserStorage(msg.sender);
        require(userStorageAddress == winner, "Restricted to winner");
        require(balances[userStorageAddress] > 0, "No funds to withdraw");
        // get the multisig wallet address for the platform fee
        address multiSigWallet = betManagement.getMultiSig();
        // transfer the platform fee to the multisig wallet
        require(
            fundToken.transfer(multiSigWallet, platformFee),
            "Token transfer failed"
        );
        // report the fees to the bet management contract
        betManagement.reportFeesCollected(platformFee);
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
}
