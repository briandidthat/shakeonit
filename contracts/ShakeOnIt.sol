// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./UserVault.sol";
import "./UserRegistry.sol";
import "./BetRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ShakeOnIt
 * @notice System coordinator. Deploys UserVault, UserRegistry, and BetRegistry
 *         in one atomic transaction and wires all cross-contract roles. The owner
 *         (a multisig) is the sole authority over token allowlisting, platform
 *         config, and BetRegistry upgrades.
 *
 * Upgrade model:
 *   BetRegistry holds all bet logic and is the only contract expected to change.
 *   UserVault and UserRegistry are immutable — they hold funds and user data.
 *   To upgrade logic: deploy a new BetRegistry (admin = address(this)), then call
 *   upgradeBetRegistry(). Roles are atomically revoked from the old and granted to
 *   the new implementation. UserVault and UserRegistry are never redeployed.
 */
contract ShakeOnIt is Ownable {
    bytes32 private constant BET_MANAGER_ROLE = keccak256("BET_MANAGER_ROLE");

    UserVault public immutable userVault;
    UserRegistry public immutable userRegistry;
    BetRegistry public betRegistry;

    event SystemDeployed(
        address indexed userVault,
        address indexed userRegistry,
        address indexed betRegistry,
        address platformAddress
    );
    event BetRegistryUpgraded(address indexed oldRegistry, address indexed newRegistry);

    /**
     * @param multiSig   Address that owns this contract and controls all admin actions.
     * @param platform   Address that receives platform fees (can be updated later).
     */
    constructor(address multiSig, address platform) Ownable(multiSig) {
        // multiSig zero-address is already caught by Ownable's constructor.
        require(platform != address(0), "Invalid platform address");

        // Deploy storage layer — this contract is their permanent admin.
        userVault = new UserVault(address(this));
        userRegistry = new UserRegistry(address(this));

        // Deploy logic layer.
        betRegistry = new BetRegistry(
            address(this),
            platform,
            address(userVault),
            address(userRegistry)
        );

        // Wire BET_MANAGER_ROLE: only BetRegistry may move balances or record outcomes.
        userVault.grantRole(BET_MANAGER_ROLE, address(betRegistry));
        userRegistry.grantRole(BET_MANAGER_ROLE, address(betRegistry));

        emit SystemDeployed(address(userVault), address(userRegistry), address(betRegistry), platform);
    }

    // ─── Upgrade ──────────────────────────────────────────────────────────────

    /**
     * @notice Replaces the active BetRegistry with a new implementation.
     * @dev    The new contract must be deployed with address(this) as its admin
     *         before calling this function. Roles are atomically transferred.
     * @param  newRegistry Address of the already-deployed replacement BetRegistry.
     */
    function upgradeBetRegistry(address newRegistry) external onlyOwner {
        require(newRegistry != address(0), "Invalid address");
        require(newRegistry != address(betRegistry), "Already current registry");
        require(betRegistry.getActiveBetCount() == 0, "Registry has active bets");

        address old = address(betRegistry);

        // Revoke access from the outgoing implementation.
        userVault.revokeRole(BET_MANAGER_ROLE, old);
        userRegistry.revokeRole(BET_MANAGER_ROLE, old);

        // Grant access to the incoming implementation.
        userVault.grantRole(BET_MANAGER_ROLE, newRegistry);
        userRegistry.grantRole(BET_MANAGER_ROLE, newRegistry);

        betRegistry = BetRegistry(newRegistry);

        emit BetRegistryUpgraded(old, newRegistry);
    }

    // ─── Config ───────────────────────────────────────────────────────────────

    /**
     * @notice Adds or removes a token from the vault allowlist.
     *         Only allowed tokens can be deposited and used for bets.
     */
    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        userVault.setTokenAllowed(token, allowed);
    }

    /**
     * @notice Updates the address that receives platform fees on settled bets.
     */
    function setPlatformAddress(address newPlatform) external onlyOwner {
        betRegistry.setPlatformAddress(newPlatform);
    }
}
