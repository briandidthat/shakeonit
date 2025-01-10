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
    mapping(address => bool) isBet;
    mapping(address => uint256) public balances;
    mapping(address => BetDetails) public betDetailsRegistry;

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
     * @dev Grant approval to a spender
     * @param _token address of the token
     * @param _spender address of the spender
     * @param _amount amount to approve
     */
    function grantApproval(
        address _token,
        address _spender,
        uint256 _amount
    ) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        // approve the spender to spend the amount
        IERC20(_token).approve(_spender, _amount);
    }

    /**
     * @dev Revoke approval to a spender
     * @param _token address of the token
     * @param _spender address of the spender
     */
    function revokeApproval(
        address _token,
        address _spender
    ) external onlyOwner {
        // set the approval to 0
        IERC20(_token).approve(_spender, 0);
    }

    /**
     * @notice Saves or updates bet details in storage
     * @dev Can only be called by addresses with BET_MANAGEMENT_ROLE
     * @param _betDetails Struct containing all bet information including contract address, status, and winner
     * @custom:throws Reverts if caller doesn't have BET_MANAGEMENT_ROLE
     * @custom:updates isBet mapping - marks bet contract address as valid
     * @custom:updates deployedBets array - adds new bet contract addresses
     * @custom:updates wins/losses counters based on bet outcome
     * @custom:updates betDetailsRegistry mapping with latest bet details
     */
    function saveBet(BetDetails memory _betDetails) external onlyBetManagement {
        address betContract = _betDetails.betContract;
        if (!isBet[betContract]) {
            isBet[betContract] = true;
            deployedBets.push(betContract);
        }
        if (_betDetails.status == BetStatus.WON) {
            if (_betDetails.winner == address(this)) {
                wins++;
            } else {
                losses++;
            }
        }
        betDetailsRegistry[betContract] = _betDetails;
    }

    function getAllBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getBetDetails(
        address _betContract
    ) external view returns (BetDetails memory) {
        return betDetailsRegistry[_betContract];
    }

    /**
     * @dev Get balance of the provided token
     * @return uint256 balance of the token
     */
    function getTokenBalance(address _token) external view returns (uint256) {
        return balances[_token];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function getUsername() external view returns (string memory) {
        return username;
    }
}
