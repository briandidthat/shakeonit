// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title UserRegistry
 * @notice Manages user registration, username uniqueness, and win/loss records.
 *         Deliberately holds no funds — that responsibility belongs to UserVault.
 *         BetRegistry holds BET_MANAGER_ROLE to record outcomes after bets settle.
 */
contract UserRegistry is AccessControl {
    bytes32 public constant BET_MANAGER_ROLE = keccak256("BET_MANAGER_ROLE");

    struct UserProfile {
        bytes32 username;
        uint256 wins;
        uint256 losses;
    }

    mapping(address user => UserProfile) private _profiles;
    mapping(address user => bool) private _registered;
    mapping(bytes32 username => address owner) private _usernameOwner;

    event UserRegistered(address indexed user, bytes32 indexed username);
    event WinRecorded(address indexed user, uint256 totalWins);
    event LossRecorded(address indexed user, uint256 totalLosses);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ─── User-facing ──────────────────────────────────────────────────────────

    function register(bytes32 username) external {
        require(!_registered[msg.sender], "Already registered");
        require(username != bytes32(0), "Username cannot be empty");
        require(_usernameOwner[username] == address(0), "Username already taken");

        _profiles[msg.sender] = UserProfile({ username: username, wins: 0, losses: 0 });
        _registered[msg.sender] = true;
        _usernameOwner[username] = msg.sender;

        emit UserRegistered(msg.sender, username);
    }

    // ─── BetRegistry-facing (privileged) ──────────────────────────────────────

    function recordWin(address user) external onlyRole(BET_MANAGER_ROLE) {
        require(_registered[user], "User not registered");
        uint256 wins = ++_profiles[user].wins;
        emit WinRecorded(user, wins);
    }

    function recordLoss(address user) external onlyRole(BET_MANAGER_ROLE) {
        require(_registered[user], "User not registered");
        uint256 losses = ++_profiles[user].losses;
        emit LossRecorded(user, losses);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    function getProfile(address user) external view returns (UserProfile memory) {
        require(_registered[user], "User not registered");
        return _profiles[user];
    }

    function isRegistered(address user) external view returns (bool) {
        return _registered[user];
    }

    function usernameOwner(bytes32 username) external view returns (address) {
        return _usernameOwner[username];
    }
}
