// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./DataCenter.sol";
import "./Bet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Arbiter is IShakeOnIt, Ownable {
    enum Status {
        ACTIVE,
        SUSPENDED,
        BLOCKED
    }
    address private dataCenter;
    uint256 private feesCollected;
    uint256 private betsJudged;
    Status private status;
    address[] private bets;
    mapping(address => uint256) private balances;
    mapping(address => bool) public betWasDeclared;
    mapping(address => bool) public betIsActive;

    constructor(address _owner, address _dataCenter) Ownable(_owner) {
        dataCenter = _dataCenter;
        status = Status.ACTIVE;
    }

    /**
     * @notice Declares the winner of a bet and updates the contract state accordingly.
     * @dev This function can only be called by the owner of the contract.
     * @param _betContract The address of the bet contract.
     * @param _winner The address of the winner to be declared.
     */
    function declareWinner(
        address _betContract,
        address _winner
    ) external onlyOwner {
        require(betIsActive[_betContract], "Bet is not active");
        require(!betWasDeclared[_betContract], "Winner already declared");
        // declare winner
        Bet bet = Bet(_betContract);
        uint256 payment = bet.declareWinner(_winner);
        // update stats
        feesCollected += payment;
        betsJudged++;
        // update bet state
        betWasDeclared[_betContract] = true;
        betIsActive[_betContract] = false;
        // update arbiter balance
        address token = bet.getFundToken();
        balances[token] += payment;
    }

    /**
     * @notice Collect fees from arbiter contract
     * @param _token Address of the token to collect fees in
     * @param _amount Amount of tokens to collect
     * @custom:access Only owner
     */
    function collectFees(address _token, uint256 _amount) external onlyOwner {
        require(balances[_token] >= _amount, "Insufficient balance");
        // transfer fees to owner
        require(IERC20(_token).transfer(owner(), _amount), "Transfer failed");
        // update token balance
        balances[_token] -= _amount;
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

    function getStatus() external view returns (Status) {
        return Status.ACTIVE;
    }
}
