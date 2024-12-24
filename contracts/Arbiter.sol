// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./DataCenter.sol";
import "./Bet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Arbiter is IShakeOnIt, Ownable {
    enum ArbiterStatus {
        ACTIVE,
        PENDING,
        SUSPENDED,
        BLOCKED
    }
    address private arbiterManagement;
    uint256 private feesCollected;
    uint256 private betsJudged;
    ArbiterStatus private status;
    address[] private bets;
    mapping(address => uint256) private balances;
    mapping(address => bool) private betIsActive;
    mapping(address => bool) private betWasDeclared;

    constructor(address _owner, address _arbiterManagement) Ownable(_owner) {
        arbiterManagement = _arbiterManagement;
        status = ArbiterStatus.PENDING;
    }

    modifier onlyArbiterManagement() {
        require(
            msg.sender == arbiterManagement,
            "Restricted to arbiter management"
        );
        _;
    }

    /**
     * @notice Declares the winner of a bet and updates the contract state accordingly.
     * @dev This function can only be called by the owner of the contract.
     * @param _betContract The address of the bet contract.
     * @param _winner The address of the winner to be declared.
     */
    function declareWinner(
        address _betContract,
        address _winner,
        address _loser,
        uint256 _payment
    ) external onlyOwner {
        require(betIsActive[_betContract], "Bet is not active");
        require(!betWasDeclared[_betContract], "Winner already declared");
        // declare winner
        Bet bet = Bet(_betContract);
        bet.declareWinner(_winner, _loser);
        // update stats
        feesCollected += _payment;
        betsJudged++;
        // update bet state
        betWasDeclared[_betContract] = true;
        betIsActive[_betContract] = false;
        // update arbiter balance
        address token = bet.getFundToken();
        balances[token] += _payment;
    }

    /**
     * @notice Collect fees from arbiter contract. Withdrawals are suspended when arbiter is suspended.
     * @param _token Address of the token to collect fees in
     * @param _amount Amount of tokens to collect
     * @custom:access Only owner
     */
    function collectFees(address _token, uint256 _amount) external onlyOwner {
        require(balances[_token] >= _amount, "Insufficient balance");
        require(status != ArbiterStatus.SUSPENDED, "Withdrawals are suspended");
        // transfer fees to owner
        require(IERC20(_token).transfer(owner(), _amount), "Transfer failed");
        // update token balance
        balances[_token] -= _amount;
    }

    /**
     * @notice Penalize arbiter contract. Withdrawals are suspended when arbiter is suspended.
     * @param _token Address of the token to penalize in
     * @param _amount Amount of tokens to penalize
     * @custom:access Only arbiter management
     */
    function penalize(
        address _token,
        uint256 _amount
    ) external onlyArbiterManagement {
        require(balances[_token] >= _amount, "Insufficient balance");
        require(status == ArbiterStatus.SUSPENDED, "Arbiter is not suspended");
        // transfer amount to multiSig
        address multiSig = ArbiterManagement(arbiterManagement).getMultiSig();
        // transfer fees to multiSig
        require(IERC20(_token).transfer(multiSig, _amount), "Transfer failed");
        // update token balance
        balances[_token] -= _amount;
    }

    function setArbiterStatus(
        ArbiterStatus _status
    ) external onlyArbiterManagement {
        status = _status;
    }

    function getBetsJudged() external view returns (uint256) {
        return betsJudged;
    }

    function getBets() external view returns (address[] memory) {
        return bets;
    }

    function getFeesCollected() external view returns (uint256) {
        return feesCollected;
    }

    function getBalances(address _token) external view returns (uint256) {
        return balances[_token];
    }

    function getStatus() external view returns (ArbiterStatus) {
        return status;
    }
}
