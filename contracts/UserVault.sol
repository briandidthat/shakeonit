// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title UserVault
 * @notice Custodies all user token balances. Balances are split into available
 *         (withdrawable, usable for new bets) and locked (committed to active bets).
 *         Only BetRegistry holds the BET_MANAGER_ROLE and may move funds between
 *         these buckets. Users interact only via deposit and withdraw.
 */
contract UserVault is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant BET_MANAGER_ROLE = keccak256("BET_MANAGER_ROLE");

    mapping(address token => bool) public allowedTokens;
    mapping(address user => mapping(address token => uint256)) private _available;
    mapping(address user => mapping(address token => uint256)) private _locked;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Locked(address indexed user, address indexed token, uint256 amount);
    event Unlocked(address indexed user, address indexed token, uint256 amount);
    event Credited(address indexed user, address indexed token, uint256 amount);
    event Debited(address indexed user, address indexed token, uint256 amount);
    event TokenAllowlistUpdated(address indexed token, bool allowed);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ─── User-facing ──────────────────────────────────────────────────────────

    function deposit(address token, uint256 amount) external nonReentrant {
        require(allowedTokens[token], "Token not allowed");
        require(amount > 0, "Amount must be greater than 0");
        // CEI: update state before external call
        _available[msg.sender][token] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        require(_available[msg.sender][token] >= amount, "Insufficient available balance");
        // CEI: update state before external call
        _available[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    // ─── BetRegistry-facing (privileged) ──────────────────────────────────────

    /// @notice Moves `amount` from available → locked when a user commits to a bet.
    function lock(address user, address token, uint256 amount) external onlyRole(BET_MANAGER_ROLE) {
        require(_available[user][token] >= amount, "Insufficient available balance");
        _available[user][token] -= amount;
        _locked[user][token] += amount;
        emit Locked(user, token, amount);
    }

    /// @notice Moves `amount` from locked → available when a bet is cancelled or refunded.
    function unlock(address user, address token, uint256 amount) external onlyRole(BET_MANAGER_ROLE) {
        require(_locked[user][token] >= amount, "Insufficient locked balance");
        _locked[user][token] -= amount;
        _available[user][token] += amount;
        emit Unlocked(user, token, amount);
    }

    /// @notice Removes `amount` from locked without returning it (funds redistributed elsewhere via credit).
    function debit(address user, address token, uint256 amount) external onlyRole(BET_MANAGER_ROLE) {
        require(_locked[user][token] >= amount, "Insufficient locked balance");
        _locked[user][token] -= amount;
        emit Debited(user, token, amount);
    }

    /// @notice Adds `amount` to a user's available balance (winnings, fee income, refunds).
    function credit(address user, address token, uint256 amount) external onlyRole(BET_MANAGER_ROLE) {
        _available[user][token] += amount;
        emit Credited(user, token, amount);
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    function setTokenAllowed(address token, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedTokens[token] = allowed;
        emit TokenAllowlistUpdated(token, allowed);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    function availableBalance(address user, address token) external view returns (uint256) {
        return _available[user][token];
    }

    function lockedBalance(address user, address token) external view returns (uint256) {
        return _locked[user][token];
    }

    function totalBalance(address user, address token) external view returns (uint256) {
        return _available[user][token] + _locked[user][token];
    }
}
