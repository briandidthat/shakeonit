// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./Restricted.sol";
import "./Bet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UserStorage is IShakeOnIt {
    string private username;
    uint256 private wins;
    uint256 private losses;
    address private owner;
    address private betManagement;
    address[] public deployedBets;
    address[] private tokens;
    mapping(address => bool) private isBet;
    mapping(address => bool) private hasToken;
    mapping(address => uint256) private balances;
    mapping(address => BetDetails) private betDetailsRegistry;

    event BetSaved(address indexed betContract, BetStatus status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Restricted to owner");
        _;
    }

    modifier onlyBetManagement() {
        require(msg.sender == betManagement, "Restricted to bet management");
        _;
    }

    constructor(
        string memory _username,
        address _owner,
        address _betManagement
    ) {
        username = _username;
        owner = _owner;
        betManagement = _betManagement;
    }

    /**
     * @dev Deposit tokens
     * @param _token address of the token
     * @param _amount amount of the token
     */
    function deposit(address _token, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_token);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        if (!hasToken[_token]) {
            tokens.push(_token);
            hasToken[_token] = true;
            // approve the bet management contract to spend the token
            token.approve(betManagement, type(uint256).max);
        }
        balances[_token] += _amount;
    }

    /**
     * @dev Withdraw tokens
     * @param _token address of the token
     * @param _amount amount of the token
     */
    function withdraw(address _token, uint256 _amount) external onlyOwner {
        require(balances[_token] >= _amount, "Insufficient balance");
        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        balances[_token] -= _amount;
    }

    /**
     * @dev Grant approval to a the bet management contract to spend a token
     * @param _token address of the token
     * @param _amount amount to approve
     */
    function grantApproval(address _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        // approve the spender to spend the amount
        require(
            IERC20(_token).approve(betManagement, _amount),
            "Approval failed"
        );
    }

    /**
     * @dev Revoke approval to a the bet management contract to spend a token
     * @param _token address of the token
     */
    function revokeApproval(address _token) external onlyOwner {
        // set the approval to 0
        IERC20(_token).approve(betManagement, 0);
    }

    /**
     * @notice Saves or updates bet details in storage
     * @dev Can only be called by addresses with BET_MANAGEMENT_ROLE
     * @param _betDetails Struct containing all bet information including contract address, status, etc
     * @custom:throws Reverts if caller doesn't have BET_MANAGEMENT_ROLE
     * @custom:updates isBet mapping - marks bet contract address as valid
     * @custom:updates deployedBets array - adds new bet contract addresses
     * @custom:updates wins/losses counters based on bet outcome
     * @custom:updates betDetailsRegistry mapping with latest bet details
     */
    function saveBet(BetDetails memory _betDetails) external onlyBetManagement {
        address betContract = _betDetails.betContract;
        address token = _betDetails.token;
        address storageAddr = address(this);
        uint256 tokenBalance = balances[token];

        if (!isBet[betContract]) {
            isBet[betContract] = true;
            deployedBets.push(betContract);
            if (_betDetails.arbiter.storageAddress != storageAddr) {
                balances[token] = tokenBalance - _betDetails.stake;
            }
        }

        if (_betDetails.status == BetStatus.WON) {
            if (_betDetails.winner == storageAddr) {
                wins++;
                balances[token] = tokenBalance + _betDetails.payout;
            } else if (_betDetails.loser == storageAddr) {
                // we've already updated balance upon creating/accepting bet
                losses++;
            } else if (_betDetails.arbiter.storageAddress == storageAddr) {
                // update with arbiter fee
                balances[token] = tokenBalance + _betDetails.arbiterFee;
            }
        } else if (_betDetails.status == BetStatus.CANCELLED) {
            if (_betDetails.initiator.storageAddress == storageAddr) {
                balances[token] += _betDetails.stake;
            }
        }

        betDetailsRegistry[betContract] = _betDetails;
        emit BetSaved(betContract, _betDetails.status);
    }

    // will only be called if the bet management contract is upgraded or needs to be
    function setNewBetManagement(address _newBetManagement) external onlyOwner {
        betManagement = _newBetManagement;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getUsername() external view returns (string memory) {
        return username;
    }

    function getWins() external view returns (uint256) {
        return wins;
    }

    function getLosses() external view returns (uint256) {
        return losses;
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getBetDetails(
        address _betContract
    ) external view returns (BetDetails memory) {
        return betDetailsRegistry[_betContract];
    }

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @dev Get balance of the provided token
     * @return uint256 balance of the token
     */
    function getTokenBalance(address _token) external view returns (uint256) {
        return balances[_token];
    }
}
