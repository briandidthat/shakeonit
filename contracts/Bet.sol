// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./BetManagement.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DataCenter.sol";

contract Bet is IShakeOnIt {
    User private creator;
    User private challenger;
    User private arbiter;
    User private winner;
    User private loser;
    uint256 private stake;
    uint256 private arbiterFee;
    uint256 private platformFee;
    uint256 private payout;
    string private condition;
    BetType private betType;
    BetStatus private status;
    BetManagement private betManagement;
    IERC20 private token;
    mapping(address => uint256) private balances;

    modifier onlyArbiter() {
        require(msg.sender == arbiter.signer, "Restricted to arbiter");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == creator.signer, "Restricted to creator");
        _;
    }

    modifier onlyWinner() {
        require(msg.sender == winner.signer, "Restricted to winner");
        _;
    }

    constructor(BetRequest memory _betRequest) {
        betType = _betRequest.betType; // 0 for OPEN, 1 for PRIVATE
        token = IERC20(_betRequest.token);
        creator = _betRequest.creator;
        arbiter = _betRequest.arbiter;
        stake = _betRequest.stake;
        arbiterFee = _betRequest.arbiterFee;
        platformFee = _betRequest.platformFee;
        payout = _betRequest.payout;
        status = BetStatus.CREATED;
        condition = _betRequest.condition;
        if (_betRequest.betType == BetType.PRIVATE_BET) {
            challenger = _betRequest.challenger;
        }

        betManagement = BetManagement(msg.sender);
    }

    // External functions

    /**
     * @notice Updates the balance of the creator after deployment. Will only be called once.
     * @param _token The address of the token contract
     * @param _stake The amount of stake to be funded by the creator
     * @dev This function can only be called by the BetManagement contract
     * @dev This function will validate the bet state, stake amount and token address.
     */
    function updateBalance(address _token, uint256 _stake) external {
        require(msg.sender == address(betManagement), "Restricted to bet mgmt");
        require(status == BetStatus.CREATED, "Already Initiated");
        require(_stake == stake, "Invalid stake amount");
        require(_token == address(token), "Invalid token address");

        // update the status of the bet
        status = BetStatus.INITIATED;
        // update balance of the creator
        balances[creator.userContract] = _stake;
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(User calldata _challenger) external {
        // validate the status of the bet
        require(
            status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        // validate the challenger
        require(
            msg.sender != creator.signer && msg.sender != arbiter.signer,
            "Invalid challenger"
        );
        // if the bet is private, only the challenger can accept the bet
        if (betType == BetType.PRIVATE_BET) {
            require(
                msg.sender == challenger.signer,
                "Only the challenger can accept the bet"
            );
        }

        require(
            balances[_challenger.userContract] == 0,
            "Participant has already funded the escrow"
        );

        // update the challenger
        challenger = _challenger;
        // update the status of the bet
        status = BetStatus.FUNDED;
        // update the balance of the challenger
        balances[_challenger.userContract] = stake;
        balances[arbiter.userContract] = arbiterFee;
        // recieve the stake from the challenger
        betManagement.acceptBet(_buildBetDetails());
    }

    /**
     * @notice Cancels the bet and refunds the creator.
     * @dev This function can only be called by the creator.
     */
    function cancelBet() external onlyCreator {
        require(
            status == BetStatus.CREATED || status == BetStatus.INITIATED,
            "Bet must be in initiated status"
        );
        require(
            token.transfer(creator.userContract, stake),
            "Token transfer failed"
        );

        // update the balance of the creator
        balances[creator.userContract] = 0;
        status = BetStatus.CANCELLED;
        // report the cancellation to the data center
        betManagement.reportCancellation(_buildBetDetails());
    }

    /**
     * @notice Declares the winner of the bet and pays the arbiter.
     * @dev This function can only be called by the arbiter.
     * @param _winner The address of the participant who is declared the winner.
     */
    function declareWinner(User memory _winner) external onlyArbiter {
        // validate the status of the bet
        require(status == BetStatus.FUNDED, "Bet has not been funded yet");

        address winnerAddress = _winner.userContract;
        address arbiterAddress = arbiter.userContract;

        // validate the participants
        require(
            winnerAddress == creator.userContract ||
                winnerAddress == challenger.userContract,
            "Invalid winner"
        );
        // validate the loser
        User memory _loser = winnerAddress == creator.userContract
            ? challenger
            : creator;

        // get the multiSig wallet address
        address multiSigWallet = betManagement.getMultiSig();

        // transfer the platform fee to the multisig wallet
        require(
            token.transfer(multiSigWallet, platformFee),
            "Token transfer failed"
        );
        // transfer the arbiter fee to the arbiter
        require(
            token.transfer(arbiterAddress, arbiterFee),
            "Token transfer to arbiter failed"
        );
        // update the balance of the arbiter
        balances[arbiterAddress] = 0;
        // update the balance of the participants
        balances[winnerAddress] = payout;
        balances[_loser.userContract] = 0;
        // assign the winner and loser
        winner = _winner;
        loser = _loser;
        // update the status of the bet
        status = BetStatus.WON;
        // report the winner to the bet management contract
        betManagement.reportWinnerDeclared(_buildBetDetails());
    }

    function forfeit() external {
        require(status == BetStatus.FUNDED, "Bet must be in funded state");
        require(
            msg.sender == creator.signer || msg.sender == challenger.signer,
            "Only participants can forfeit"
        );

        if (msg.sender == creator.signer) {
            winner = challenger;
            balances[creator.userContract] = 0;
            balances[challenger.userContract] = payout + arbiterFee;
        } else {
            winner = creator;
            balances[creator.userContract] = 0;
            balances[challenger.userContract] = payout + arbiterFee;
        }
        balances[arbiter.userContract] = 0;

        // get the multiSig wallet address
        address multiSigWallet = betManagement.getMultiSig();
        // transfer the platform fee to the multisig wallet
        require(
            token.transfer(multiSigWallet, platformFee),
            "Token transfer failed"
        );
        // report the winner to the bet management contract
        betManagement.reportWinnerDeclared(_buildBetDetails());
    }

    function withdrawEarnings() external onlyWinner {
        require(status == BetStatus.WON, "Bet has not been declared won yet");

        address winnerAddress = winner.userContract;
        require(balances[winnerAddress] > 0, "No funds to withdraw");
        // transfer the funds to the winner
        require(token.transfer(winnerAddress, payout), "Token transfer failed");
        // update the balance of the participant
        balances[winnerAddress] = 0;
        // update the status of the bet
        status = BetStatus.SETTLED;
        // report the settlement to the bet management contract
        betManagement.reportBetSettled(_buildBetDetails());
    }

    // Internal functions

    function _buildBetDetails() internal view returns (BetDetails memory) {
        return
            BetDetails({
                betType: betType,
                status: status,
                betContract: address(this),
                token: address(token),
                creator: creator.userContract,
                arbiter: arbiter.userContract,
                challenger: challenger.userContract,
                winner: winner.userContract,
                loser: loser.userContract,
                stake: stake,
                arbiterFee: arbiterFee,
                platformFee: platformFee,
                payout: payout
            });
    }

    // View functions

    function getPayout() external view returns (uint256) {
        return payout;
    }

    function getArbiter() external view returns (address) {
        return arbiter.userContract;
    }

    function getCreator() external view returns (address) {
        return creator.userContract;
    }

    function getChallenger() external view returns (address) {
        return challenger.userContract;
    }

    function getStake() external view returns (uint256) {
        return stake;
    }

    function getWinner() external view returns (address) {
        require(status != BetStatus.INITIATED, "Bet has not been declared yet");
        return winner.userContract;
    }

    function getLoser() external view returns (address) {
        require(status != BetStatus.INITIATED, "Bet has not been declared yet");
        return loser.userContract;
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

    function getBetDetails()
        external
        view
        returns (BetDetails memory _betDetails)
    {
        _betDetails = _buildBetDetails();
    }
}
