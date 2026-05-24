// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./UserVault.sol";
import "./UserRegistry.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BetRegistry
 * @notice All bet lifecycle logic. Holds no tokens — balances live entirely in
 *         UserVault. Requires BET_MANAGER_ROLE on both UserVault and UserRegistry.
 *
 * State machine:
 *   OPEN ──acceptBet──► MATCHED ──declareWinner──► SETTLED
 *    │                     │
 *   cancel              forfeit
 *   decline             claimTimeout (after deadline)
 *    │                     │
 *  CANCELLED ◄─────────────┘
 */
contract BetRegistry is AccessControl {
    enum BetType {
        OPEN,
        PRIVATE
    }

    enum BetStatus {
        OPEN,
        MATCHED,
        SETTLED,
        CANCELLED,
        FORFEITED
    }

    struct BetState {
        BetType betType;
        BetStatus status;
        address token;
        address creator;
        address challenger;
        address arbiter;
        address winner;
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
        uint256 deadline;
        string condition;
    }

    struct BetRequest {
        BetType betType;
        address token;
        address arbiter;
        address challenger; // zero address for OPEN bets
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 deadline;
        string condition;
    }

    uint256 private constant TIMEOUT_FEE_BPS = 500; // 5% per participant on arbiter no-show
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant MAX_BATCH_SIZE = 50;

    uint256 private _betCount;
    uint256 private _activeBetCount;
    address public platformAddress;
    UserVault public immutable vault;
    UserRegistry public immutable registry;

    mapping(uint256 => BetState) private _bets;

    event BetCreated(
        uint256 indexed betId,
        address indexed creator,
        address indexed arbiter,
        address token,
        uint256 stake,
        uint256 arbiterFee,
        uint256 platformFee,
        uint256 deadline,
        address challenger, // address(0) for OPEN bets
        BetType betType
    );
    event BetDeclined(
        uint256 indexed betId,
        address indexed challenger,
        address indexed creator,
        address token,
        uint256 stake
    );
    event BetMatched(
        uint256 indexed betId,
        address indexed challenger,
        address token,
        uint256 stake
    );
    event BetSettled(
        uint256 indexed betId,
        address indexed winner,
        address indexed loser,
        address token,
        uint256 payout,
        uint256 arbiterFee,
        uint256 platformFee
    );
    event BetCancelled(
        uint256 indexed betId,
        address indexed creator,
        address token,
        uint256 stake
    );
    event BetForfeited(
        uint256 indexed betId,
        address indexed forfeiter,
        address indexed winner,
        address token,
        uint256 payout,
        uint256 platformFee
    );
    event BetRefunded(
        uint256 indexed betId,
        address indexed creator,
        address indexed challenger,
        address token,
        uint256 refundPerParticipant,
        uint256 platformFee
    );
    event PlatformAddressUpdated(address indexed oldAddress, address indexed newAddress);

    constructor(
        address admin,
        address _platformAddress,
        address _vault,
        address _registry
    ) {
        require(_platformAddress != address(0), "Invalid platform address");
        require(_vault != address(0), "Invalid vault address");
        require(_registry != address(0), "Invalid registry address");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        platformAddress = _platformAddress;
        vault = UserVault(_vault);
        registry = UserRegistry(_registry);
    }

    // ─── Bet lifecycle ────────────────────────────────────────────────────────

    /**
     * @notice Creates a new bet and locks the creator's stake.
     * @dev Payout is derived on-chain as stake*2 - arbiterFee - platformFee to
     *      prevent caller-supplied mismatches.
     */
    function createBet(BetRequest calldata request) external returns (uint256 betId) {
        require(registry.isRegistered(msg.sender), "Creator not registered");
        require(registry.isRegistered(request.arbiter), "Arbiter not registered");
        require(request.arbiter != msg.sender, "Arbiter cannot be creator");
        require(request.stake > 0, "Stake must be greater than 0");
        require(request.platformFee > 0, "Platform fee must be greater than 0");
        require(vault.allowedTokens(request.token), "Token not allowed");
        require(request.deadline > block.timestamp, "Deadline must be in the future");
        require(
            request.stake * 2 > request.arbiterFee + request.platformFee,
            "Fees exceed total stake"
        );

        if (request.betType == BetType.PRIVATE) {
            require(request.challenger != address(0), "Challenger required for private bet");
            require(registry.isRegistered(request.challenger), "Challenger not registered");
            require(request.challenger != msg.sender, "Challenger cannot be creator");
            require(request.challenger != request.arbiter, "Challenger cannot be arbiter");
        }

        uint256 payout = request.stake * 2 - request.arbiterFee - request.platformFee;

        betId = ++_betCount;
        ++_activeBetCount;
        _bets[betId] = BetState({
            betType: request.betType,
            status: BetStatus.OPEN,
            token: request.token,
            creator: msg.sender,
            challenger: request.betType == BetType.PRIVATE ? request.challenger : address(0),
            arbiter: request.arbiter,
            winner: address(0),
            stake: request.stake,
            arbiterFee: request.arbiterFee,
            platformFee: request.platformFee,
            payout: payout,
            deadline: request.deadline,
            condition: request.condition
        });

        vault.lock(msg.sender, request.token, request.stake);

        emit BetCreated(
            betId,
            msg.sender,
            request.arbiter,
            request.token,
            request.stake,
            request.arbiterFee,
            request.platformFee,
            request.deadline,
            request.betType == BetType.PRIVATE ? request.challenger : address(0),
            request.betType
        );
    }

    /**
     * @notice Accepts an open bet and locks the challenger's stake.
     */
    function acceptBet(uint256 betId) external {
        BetState storage bet = _bets[betId];
        require(bet.status == BetStatus.OPEN, "Bet is not open");
        require(registry.isRegistered(msg.sender), "Challenger not registered");
        require(msg.sender != bet.creator, "Creator cannot accept own bet");
        require(msg.sender != bet.arbiter, "Arbiter cannot accept bet");
        require(block.timestamp < bet.deadline, "Bet deadline has passed");

        if (bet.betType == BetType.PRIVATE) {
            require(msg.sender == bet.challenger, "Not the designated challenger");
        }

        bet.challenger = msg.sender;
        bet.status = BetStatus.MATCHED;

        vault.lock(msg.sender, bet.token, bet.stake);

        emit BetMatched(betId, msg.sender, bet.token, bet.stake);
    }

    /**
     * @notice Arbiter declares the winner. Distributes payout, arbiter fee, and
     *         platform fee via UserVault credits. Records win/loss in UserRegistry.
     */
    function declareWinner(uint256 betId, address winner) external {
        BetState storage bet = _bets[betId];
        require(msg.sender == bet.arbiter, "Only arbiter can declare winner");
        require(bet.status == BetStatus.MATCHED, "Bet is not matched");
        require(block.timestamp < bet.deadline, "Arbitration window has closed");
        require(winner == bet.creator || winner == bet.challenger, "Invalid winner");

        address loser = winner == bet.creator ? bet.challenger : bet.creator;

        bet.winner = winner;
        bet.status = BetStatus.SETTLED;
        --_activeBetCount;

        vault.debit(bet.creator, bet.token, bet.stake);
        vault.debit(bet.challenger, bet.token, bet.stake);
        vault.credit(winner, bet.token, bet.payout);
        vault.credit(bet.arbiter, bet.token, bet.arbiterFee);
        vault.credit(platformAddress, bet.token, bet.platformFee);

        registry.recordWin(winner);
        registry.recordLoss(loser);

        emit BetSettled(betId, winner, loser, bet.token, bet.payout, bet.arbiterFee, bet.platformFee);
    }

    /**
     * @notice Creator cancels an unmatched bet and recovers their stake.
     *         Anyone may cancel once the deadline has passed — protects creators
     *         who go inactive and allows keepers to clean up expired open bets.
     */
    function cancel(uint256 betId) external {
        BetState storage bet = _bets[betId];
        require(bet.status == BetStatus.OPEN, "Bet is not open");
        require(
            msg.sender == bet.creator || block.timestamp >= bet.deadline,
            "Only creator can cancel before deadline"
        );

        bet.status = BetStatus.CANCELLED;
        --_activeBetCount;
        vault.unlock(bet.creator, bet.token, bet.stake);

        emit BetCancelled(betId, bet.creator, bet.token, bet.stake);
    }

    /**
     * @notice Designated challenger declines a private bet, unlocking the creator's stake.
     */
    function decline(uint256 betId) external {
        BetState storage bet = _bets[betId];
        require(bet.betType == BetType.PRIVATE, "Not a private bet");
        require(bet.status == BetStatus.OPEN, "Bet is not open");
        require(msg.sender == bet.challenger, "Not the designated challenger");

        bet.status = BetStatus.CANCELLED;
        --_activeBetCount;
        vault.unlock(bet.creator, bet.token, bet.stake);

        emit BetDeclined(betId, msg.sender, bet.creator, bet.token, bet.stake);
    }

    /**
     * @notice A participant forfeits. The winner receives the full payout plus the
     *         arbiter fee (no arbitration was needed). Platform fee still applies.
     */
    function forfeit(uint256 betId) external {
        BetState storage bet = _bets[betId];
        require(bet.status == BetStatus.MATCHED, "Bet is not matched");
        require(
            msg.sender == bet.creator || msg.sender == bet.challenger,
            "Only participants can forfeit"
        );

        address winner = msg.sender == bet.creator ? bet.challenger : bet.creator;
        address loser = msg.sender;

        bet.winner = winner;
        bet.status = BetStatus.FORFEITED;
        --_activeBetCount;

        vault.debit(bet.creator, bet.token, bet.stake);
        vault.debit(bet.challenger, bet.token, bet.stake);
        // arbiter fee returns to winner since no arbitration took place
        vault.credit(winner, bet.token, bet.payout + bet.arbiterFee);
        vault.credit(platformAddress, bet.token, bet.platformFee);

        registry.recordWin(winner);
        registry.recordLoss(loser);

        emit BetForfeited(betId, loser, winner, bet.token, bet.payout, bet.platformFee);
    }

    /**
     * @notice Either participant may claim a full refund once the arbiter deadline
     *         has passed without a declaration. Both stakes are unlocked.
     */
    function claimTimeout(uint256 betId) external {
        BetState storage bet = _bets[betId];
        require(bet.status == BetStatus.MATCHED, "Bet is not matched");
        require(block.timestamp >= bet.deadline, "Deadline has not passed");

        bet.status = BetStatus.CANCELLED;
        --_activeBetCount;

        uint256 fee = bet.stake * TIMEOUT_FEE_BPS / BPS_DENOMINATOR;
        uint256 refund = bet.stake - fee;

        vault.debit(bet.creator, bet.token, bet.stake);
        vault.debit(bet.challenger, bet.token, bet.stake);
        vault.credit(bet.creator, bet.token, refund);
        vault.credit(bet.challenger, bet.token, refund);
        vault.credit(platformAddress, bet.token, fee * 2);

        emit BetRefunded(betId, bet.creator, bet.challenger, bet.token, refund, fee * 2);
    }

    /**
     * @notice Processes up to MAX_BATCH_SIZE expired bets in one transaction.
     *         Invalid or already-settled IDs are silently skipped, making this
     *         safe for keeper automation. Reverts if betIds exceeds MAX_BATCH_SIZE.
     */
    function batchClaimTimeout(uint256[] calldata betIds) external {
        require(betIds.length <= MAX_BATCH_SIZE, "Exceeds batch limit");

        for (uint256 i = 0; i < betIds.length; i++) {
            BetState storage bet = _bets[betIds[i]];
            if (bet.status != BetStatus.MATCHED || block.timestamp < bet.deadline) continue;

            bet.status = BetStatus.CANCELLED;
            --_activeBetCount;

            uint256 fee = bet.stake * TIMEOUT_FEE_BPS / BPS_DENOMINATOR;
            uint256 refund = bet.stake - fee;

            vault.debit(bet.creator, bet.token, bet.stake);
            vault.debit(bet.challenger, bet.token, bet.stake);
            vault.credit(bet.creator, bet.token, refund);
            vault.credit(bet.challenger, bet.token, refund);
            vault.credit(platformAddress, bet.token, fee * 2);

            emit BetRefunded(betIds[i], bet.creator, bet.challenger, bet.token, refund, fee * 2);
        }
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    function setPlatformAddress(address _platformAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_platformAddress != address(0), "Zero address not allowed");
        emit PlatformAddressUpdated(platformAddress, _platformAddress);
        platformAddress = _platformAddress;
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    function getBet(uint256 betId) external view returns (BetState memory) {
        return _bets[betId];
    }

    function getBetCount() external view returns (uint256) {
        return _betCount;
    }

    function getActiveBetCount() external view returns (uint256) {
        return _activeBetCount;
    }
}
