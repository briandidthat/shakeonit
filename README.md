# ShakeOnIt Protocol

ShakeOnIt is a decentralized peer-to-peer betting protocol built on Base. Two parties lock a stake, a mutually agreed arbiter judges the outcome, and the winner's payout is credited automatically — no custodial intermediary, no manual settlement step.

---

## Table of Contents

- [How a Bet Works](#how-a-bet-works)
- [Architecture Overview](#architecture-overview)
- [Contract Reference](#contract-reference)
  - [ShakeOnIt.sol](#shakeonitsol)
  - [UserVault.sol](#uservaultsol)
  - [UserRegistry.sol](#userregistrysol)
  - [BetRegistry.sol](#betregistrysol)
- [The Credit System](#the-credit-system)
- [Bet Lifecycle](#bet-lifecycle)
- [Fee Structure](#fee-structure)
- [Access Control & Role Hierarchy](#access-control--role-hierarchy)
- [Upgrade Model](#upgrade-model)
- [Security Properties](#security-properties)
- [Events & Off-Chain Indexing](#events--off-chain-indexing)
- [Subgraph](#subgraph)
- [Local Development](#local-development)
- [Deployment](#deployment)
- [Testnet Contracts](#testnet-contracts)

---

## How a Bet Works

This section explains the full lifecycle of a bet in plain terms — no blockchain knowledge required.

### The three roles

| Role | Who they are | What they do |
|---|---|---|
| **Creator** | The person who proposes the bet | Sets the terms, stakes, and picks the arbiter |
| **Challenger** | The person who accepts the bet | Agrees to the terms and matches the stake |
| **Arbiter** | A trusted third party agreed upon by both sides | Watches the outcome and declares the winner |

---

### Step-by-step walkthrough

**1. Register**

Before doing anything, both the creator and challenger must register a username. This is a one-time step that creates your on-chain identity.

**2. Deposit funds**

Both parties deposit tokens (e.g. USDC) into their vault balance. Think of this like depositing chips at a casino cage — your tokens are held safely in the vault, and your balance is what you use to bet. You only need to deposit once and can use that balance across many bets.

**3. Create the bet**

The creator proposes a bet by specifying:
- What the bet is about (e.g. *"Team A wins the championship"*)
- How much each side must stake (e.g. 500 USDC each)
- Who the arbiter is and how much they earn for judging (e.g. 25 USDC)
- A platform fee (e.g. 25 USDC)
- A deadline — the date by which the arbiter must declare a winner

The creator's stake is immediately locked in the vault. It cannot be withdrawn until the bet resolves.

**4. Accept the bet**

The challenger sees the bet and accepts it. Their stake is locked too. Both sides are now committed — the bet is live.

> For **private bets**, only a specific designated challenger can accept. For **open bets**, anyone can accept first.

**5. Arbiter declares the winner**

Once the real-world outcome is known, the arbiter calls `declareWinner`. The protocol automatically:
- Credits the winner with their payout (both stakes minus fees)
- Credits the arbiter their fee
- Credits the platform its fee

No manual token transfers happen — all balances update instantly inside the vault.

**6. Withdraw**

The winner's available balance increases. They can withdraw to their wallet at any time.

---

### What if things go wrong?

| Situation | What happens |
|---|---|
| No one accepts the bet | The creator can **cancel** anytime and get their full stake back |
| One party wants to give up | Either side can **forfeit** — the other party wins automatically and receives the payout plus the arbiter fee (no arbitration was needed) |
| Arbiter never declares before the deadline | Anyone (either participant, a keeper bot, or a third party) can trigger `claimTimeout`. Both parties recover **95% of their stake**. The platform collects a 5% no-show fee from each side (10% total) to cover the inconvenience |

---

### Visual summary

```
  Creator                   Challenger                  Arbiter
     │                           │                          │
     │── register() ─────────────│── register() ────────────│── register()
     │                           │                          │
     │── deposit(500 USDC) ──────│── deposit(500 USDC)      │
     │                           │                          │
     │── createBet() ────────────────────────────────────────────────►
     │   stake=500, fees=50      │                          │
     │   [500 USDC locked]       │                          │
     ��                           │                          │
     │                           │── acceptBet() ──────────────────────►
     │                           │   [500 USDC locked]      │
     │                           │                          │
     │                           │               declareWinner(creator) ──►
     │                           │                          │
     │◄── credit 950 USDC ───────│◄─── (loser, nothing)    │◄─── credit 25 USDC
     │                           │                          │
     │── withdraw(950 USDC) ─────────────────────��───────────────────────►
```

---

## Architecture Overview

The protocol is built around four long-lived contracts. No new contract is deployed per user or per bet — all state lives in mappings, keeping gas costs flat regardless of how many users or bets exist.

```
┌──────────────────────────────────────────────────────���──┐
│                      ShakeOnIt                          │
│          (coordinator · multisig-owned · Ownable)       │
│                                                         │
│  deploys & wires ───────────────────────────────���──┐    │
└─────────────────────────────────────────────────────┼───┘
                                                      │
          ┌───────────────────────────────────────────┼──────────────────────┐
          │                                           │                      │
          ▼                                           ▼                      ▼
  ┌───────────────┐                        ┌──────────────────┐   ┌──────────────────┐
  │  UserVault    │◄──── BET_MANAGER ──────│  BetRegistry     │   │  UserRegistry    │
  │               │       ROLE             │                  │◄──│                  │
  │  all tokens   │                        │  all bet logic   │   │  profiles &      │
  │  available +  │                        │  OPEN/MATCHED/   │   │  usernames       │
  │  locked maps  │                        │  SETTLED/etc.    │   │                  │
  └───────────────┘                        └──────────────────┘   └──────────────────┘
   non-upgradeable                          upgradeable via         non-upgradeable
   holds all funds                          ShakeOnIt               holds user data
```

**Design rationale:**

| Concern | Solution |
|---|---|
| Per-bet contract deployment cost | Single `mapping(uint256 => BetState)` in `BetRegistry` |
| Per-user contract deployment cost | Single `mapping(address => UserProfile)` in `UserRegistry` |
| Mid-bet token transfers | None — all funds stay in `UserVault`; only internal balance accounting moves |
| Arbiter ghosting | `deadline` field + `claimTimeout()` refunds both parties if arbiter doesn't declare in time |
| Logic bugs post-deploy | `BetRegistry` is replaceable; `UserVault` and `UserRegistry` (which hold funds and data) are never redeployed |

---

## Contract Reference

### ShakeOnIt.sol

The system entry point and coordinator. Owned by a multisig. Deploys all three sub-contracts atomically in its constructor, wires the `BET_MANAGER_ROLE`, and exposes the only admin operations available after deployment.

**Constructor**

```solidity
constructor(address multiSig, address platform)
```

Deploys `UserVault`, `UserRegistry`, and `BetRegistry` in a single transaction, grants `BET_MANAGER_ROLE` to `BetRegistry` on both storage contracts, and emits `SystemDeployed`.

**Admin functions** (all `onlyOwner`)

| Function | Description |
|---|---|
| `upgradeBetRegistry(address newRegistry)` | Replaces the active `BetRegistry`. Revokes the role from the old implementation and grants it to the new one. **Reverts if the outgoing registry has any active (OPEN or MATCHED) bets.** |
| `setTokenAllowed(address token, bool allowed)` | Adds or removes a token from the vault's deposit allowlist. |
| `setPlatformAddress(address newPlatform)` | Updates the address that receives platform fees on settled bets. |

**Events**

| Event | Emitted when |
|---|---|
| `SystemDeployed(vault, registry, betRegistry, platformAddress)` | Constructor completes |
| `BetRegistryUpgraded(oldRegistry, newRegistry)` | `upgradeBetRegistry` succeeds |

---

### UserVault.sol

Custodies all token balances for all users. This contract **never** gets redeployed — it is the permanent home of user funds. Balances are split into two buckets per `(user, token)` pair:

- **available** — can be withdrawn or used to create/accept new bets
- **locked** — committed to an active bet, cannot be withdrawn until the bet resolves

Only addresses holding `BET_MANAGER_ROLE` (i.e. the active `BetRegistry`) may move funds between these buckets. Users interact only via `deposit` and `withdraw`.

**User functions**

| Function | Description |
|---|---|
| `deposit(address token, uint256 amount)` | Transfers `amount` of `token` from `msg.sender` into the vault and credits their available balance. Token must be allowlisted. |
| `withdraw(address token, uint256 amount)` | Transfers `amount` from the vault to `msg.sender`. Only available balance can be withdrawn — locked funds are inaccessible until their bet resolves. |

**Privileged functions** (`BET_MANAGER_ROLE` only)

| Function | Description |
|---|---|
| `lock(user, token, amount)` | Moves `amount` from available → locked when a bet is created or accepted. |
| `unlock(user, token, amount)` | Moves `amount` from locked → available when a bet is cancelled. |
| `debit(user, token, amount)` | Removes `amount` from locked without returning it (funds are redistributed to other parties via `credit`). |
| `credit(user, token, amount)` | Adds `amount` to available balance (winnings, arbiter fees, refunds). |

**View functions**

| Function | Returns |
|---|---|
| `availableBalance(user, token)` | Balance the user can withdraw or stake |
| `lockedBalance(user, token)` | Balance currently committed to active bets |
| `totalBalance(user, token)` | Sum of available and locked |

**Security notes**
- `deposit` and `withdraw` are protected by `ReentrancyGuard`
- Both follow the Check-Effects-Interactions pattern (state updated before external token call)
- Only tokens explicitly allowlisted by the `ShakeOnIt` owner can be deposited
- Fee-on-transfer and rebasing tokens must not be allowlisted — the vault credits the nominal `amount`, not the actual received amount

---

### UserRegistry.sol

Stores user profiles and enforces username uniqueness. Completely stateless with respect to funds. `BetRegistry` calls `recordWin` and `recordLoss` when bets settle.

**User functions**

| Function | Description |
|---|---|
| `register(bytes32 username)` | Registers `msg.sender` with a unique username. Reverts if the address or username is already taken. Usernames are `bytes32` encoded off-chain via `ethers.encodeBytes32String`. |

**Privileged functions** (`BET_MANAGER_ROLE` only)

| Function | Description |
|---|---|
| `recordWin(address user)` | Increments the user's win counter. |
| `recordLoss(address user)` | Increments the user's loss counter. |

**View functions**

| Function | Returns |
|---|---|
| `getProfile(address user)` | `UserProfile { username, wins, losses }` |
| `isRegistered(address user)` | `bool` |
| `usernameOwner(bytes32 username)` | Address that owns the username, or `address(0)` |

---

### BetRegistry.sol

All bet lifecycle logic lives here. Holds no tokens — every fund movement is a call into `UserVault`. This is the only contract expected to be upgraded over time.

**Enumerations**

```solidity
enum BetType   { OPEN, PRIVATE }
enum BetStatus { OPEN, MATCHED, SETTLED, CANCELLED, FORFEITED }
```

**BetState struct**

| Field | Type | Description |
|---|---|---|
| `betType` | `BetType` | OPEN (anyone can accept) or PRIVATE (designated challenger only) |
| `status` | `BetStatus` | Current lifecycle state |
| `token` | `address` | ERC-20 token used for the stake |
| `creator` | `address` | Address that created the bet |
| `challenger` | `address` | Address that accepted the bet (zero until accepted) |
| `arbiter` | `address` | Address that will judge the outcome |
| `winner` | `address` | Populated after `declareWinner` or `forfeit` |
| `stake` | `uint256` | Amount each party locks |
| `arbiterFee` | `uint256` | Fee paid to the arbiter on settlement |
| `platformFee` | `uint256` | Fee paid to the platform on settlement |
| `payout` | `uint256` | What the winner receives — derived on-chain as `stake * 2 - arbiterFee - platformFee` |
| `deadline` | `uint256` | Unix timestamp after which `claimTimeout` becomes available |
| `condition` | `string` | Human-readable bet condition |

**BetRequest struct** (passed to `createBet`)

```solidity
struct BetRequest {
    BetType  betType;
    address  token;
    address  arbiter;
    address  challenger; // address(0) for OPEN bets
    uint256  stake;
    uint256  arbiterFee;
    uint256  platformFee;
    uint256  deadline;
    string   condition;
}
```

> `payout` is not part of `BetRequest`. It is always computed on-chain from `stake * 2 - arbiterFee - platformFee`, preventing caller-supplied mismatches.

**Lifecycle functions**

| Function | Caller | From status | To status | Description |
|---|---|---|---|---|
| `createBet(BetRequest)` | Any registered user | — | `OPEN` | Validates inputs, locks creator's stake, stores bet, returns `betId` |
| `acceptBet(uint256 betId)` | Any registered user (OPEN) or designated challenger (PRIVATE) | `OPEN` | `MATCHED` | Locks challenger's stake |
| `declareWinner(uint256 betId, address winner)` | Arbiter only, before deadline | `MATCHED` | `SETTLED` | Distributes payout, arbiter fee, and platform fee |
| `cancel(uint256 betId)` | Creator only | `OPEN` | `CANCELLED` | Unlocks creator's stake |
| `forfeit(uint256 betId)` | Creator or challenger | `MATCHED` | `FORFEITED` | Forfeiting party loses their stake; winner receives `payout + arbiterFee` |
| `claimTimeout(uint256 betId)` | **Anyone**, after deadline | `MATCHED` | `CANCELLED` | Each participant receives 95% of their stake back; platform collects 5% from each side (10% total) as a no-show fee |
| `batchClaimTimeout(uint256[] betIds)` | **Anyone**, after deadline | `MATCHED` | `CANCELLED` | Processes up to 50 expired bets in one transaction. Invalid or already-settled IDs are silently skipped — designed for keeper automation |

**Validation rules for `createBet`**

- Creator and arbiter must be registered in `UserRegistry`
- Arbiter cannot be the creator
- Token must be on `UserVault`'s allowlist
- `stake > 0`, `platformFee > 0`
- `stake * 2 > arbiterFee + platformFee` (payout must be positive)
- `deadline > block.timestamp`
- For PRIVATE bets: challenger must be registered, cannot be creator or arbiter

**View functions**

| Function | Returns |
|---|---|
| `getBet(uint256 betId)` | Full `BetState` struct |
| `getBetCount()` | Total bets ever created |
| `getActiveBetCount()` | Bets currently in `OPEN` or `MATCHED` state |

---

## The Credit System

Users deposit tokens into `UserVault` once and use that balance across many bets. Tokens never leave the vault mid-bet — all movement between participants is pure internal accounting.

```
User deposits 5,000 USDC
└─► UserVault._available[user][USDC] = 5,000

User creates bet (stake = 1,000 USDC)
└─► _available[creator][USDC]: 5,000 → 4,000
    _locked[creator][USDC]:        0 → 1,000

Challenger accepts (stake = 1,000 USDC)
└─► _available[challenger][USDC]: 5,000 → 4,000
    _locked[challenger][USDC]:        0 → 1,000

Arbiter declares creator wins (payout = 1,900, arbiterFee = 50, platformFee = 50)
└─► _locked[creator][USDC]:     1,000 → 0  (debit)
    _locked[challenger][USDC]:  1,000 → 0  (debit)
    _available[creator][USDC]:  4,000 → 5,900  (credit payout)
    _available[arbiter][USDC]:      0 → 50     (credit arbiterFee)
    _available[platform][USDC]:     0 → 50     (credit platformFee)

Creator withdraws 5,900 USDC
└─► _available[creator][USDC]: 5,900 → 0
    ERC-20 transfer: vault → creator.address
```

**Token transfers happen exactly twice per user lifecycle:**
1. When the user deposits into `UserVault`
2. When the user withdraws from `UserVault`

Everything in between is integer arithmetic on mappings.

---

## Bet Lifecycle

### State machine

```
                    createBet()
                        │
                        ▼
                      OPEN ────────────────���─────────► CANCELLED
                        │          cancel()           (creator unlocked)
                        │          (creator only,
                        │          any time while OPEN)
                    acceptBet()
                        │
                        ▼
                    MATCHED ──────────────────────────► FORFEITED
                     │    │         forfeit()         (winner gets
                     │    │    (creator or challenger) payout + arbiterFee)
                     │    │
                     │    └──── claimTimeout() ──────► CANCELLED
                     │          (anyone, after         (each party gets 95%
                     │          deadline)              of stake back; platform
                     │                                 takes 5% per side)
                     │
                 declareWinner()
                (arbiter only,
                before deadline)
                     │
                     ▼
                  SETTLED
               (winner credited
                with payout)
```

### Deadline mechanics

Every bet has a `deadline` timestamp set at creation time. Its meaning differs by status:

| Status | Deadline effect |
|---|---|
| `OPEN` | `acceptBet` reverts after the deadline — the bet can no longer be accepted. Creator can still `cancel` freely. |
| `MATCHED` | `declareWinner` reverts after the deadline — the arbiter's window is permanently closed. Anyone can then call `claimTimeout` to trigger a partial refund (95% per participant). |

The deadline does not automatically trigger anything on-chain. A person or keeper bot must explicitly call `claimTimeout`. Until they do, the bet remains in `MATCHED` state.

### Forfeit vs timeout

| Situation | Mechanism | Fee impact |
|---|---|---|
| One party admits defeat | `forfeit()` | Platform fee still taken; arbiter fee goes to winner (no arbitration needed) |
| Arbiter fails to declare before deadline | `claimTimeout()` | Platform takes 5% from each side (10% total); each party receives 95% of their stake |

---

## Fee Structure

| Recipient | Source | Notes |
|---|---|---|
| Winner | `payout = stake * 2 - arbiterFee - platformFee` | Credited to `_available` in `UserVault` on `declareWinner` |
| Arbiter | `arbiterFee` | Credited on `declareWinner`; goes to winner on `forfeit` (no arbitration needed); not paid on `claimTimeout` |
| Platform | `platformFee` | Credited on `declareWinner` and `forfeit`; on `claimTimeout`, collects 5% of each participant's stake (10% total) as a no-show fee |

**Settlement invariant:** `payout + arbiterFee + platformFee = stake * 2` — holds for both `declareWinner` and `forfeit`.

**Timeout invariant:** `(refund × 2) + timeoutFee = stake * 2` where `refund = stake × 0.95` and `timeoutFee = stake × 0.10`.

---

## Access Control & Role Hierarchy

```
Multisig (owner)
    └── ShakeOnIt (Ownable)
            ├── DEFAULT_ADMIN_ROLE on UserVault
            │       └── BET_MANAGER_ROLE granted to BetRegistry
            ├── DEFAULT_ADMIN_ROLE on UserRegistry
            │       └── BET_MANAGER_ROLE granted to BetRegistry
            └── DEFAULT_ADMIN_ROLE on BetRegistry
```

| Role | Held by | Grants access to |
|---|---|---|
| `Ownable.owner` | Multisig | `upgradeBetRegistry`, `setTokenAllowed`, `setPlatformAddress` on `ShakeOnIt` |
| `DEFAULT_ADMIN_ROLE` | `ShakeOnIt` address | `grantRole` / `revokeRole` on all sub-contracts |
| `BET_MANAGER_ROLE` | Active `BetRegistry` | `lock`, `unlock`, `debit`, `credit` on `UserVault`; `recordWin`, `recordLoss` on `UserRegistry` |

Users interact directly with `UserVault` (deposit/withdraw), `UserRegistry` (register), and `BetRegistry` (bet lifecycle) — not through `ShakeOnIt`.

---

## Upgrade Model

`UserVault` and `UserRegistry` are non-upgradeable by design. They hold user funds and canonical profile data respectively — stability is more valuable than flexibility for these contracts.

`BetRegistry` holds all logic and is expected to be upgraded when bugs are found or features are added. The upgrade path is:

**1. Deploy the new implementation**
```solidity
BetRegistry newRegistry = new BetRegistry(
    address(shakeOnIt),   // admin = ShakeOnIt so it can manage roles
    platformAddress,
    address(userVault),
    address(userRegistry)
);
```

**2. Ensure the current registry has no active bets**

`upgradeBetRegistry` will revert if `betRegistry.getActiveBetCount() > 0`. Wait for all open and matched bets to reach a terminal state (settled, cancelled, or forfeited), or use `batchClaimTimeout` to close matched bets past their deadline.

**3. Call the upgrade**
```solidity
shakeOnIt.upgradeBetRegistry(address(newRegistry));
```

This atomically:
- Revokes `BET_MANAGER_ROLE` from the outgoing `BetRegistry` on both `UserVault` and `UserRegistry`
- Grants `BET_MANAGER_ROLE` to the new `BetRegistry` on both storage contracts
- Updates `ShakeOnIt.betRegistry` to point to the new address
- Emits `BetRegistryUpgraded(oldAddress, newAddress)`

All user balances and profiles remain untouched in `UserVault` and `UserRegistry`.

---

## Security Properties

### What the protocol guarantees

- **Funds are only ever in `UserVault`** — no mid-bet transfers, no per-bet escrow contracts
- **Reentrancy is blocked** — `deposit` and `withdraw` use `ReentrancyGuard`; `BetRegistry` functions mutate state before calling into `UserVault`
- **Payout math is verified on-chain** — `payout` is computed, never supplied by the caller
- **Arbiter cannot act after the deadline** — `declareWinner` reverts if `block.timestamp >= bet.deadline`
- **Upgrade cannot strand in-flight funds** — `upgradeBetRegistry` reverts if `getActiveBetCount() > 0`
- **No user can double-spend locked funds** — `lock` checks available balance; `withdraw` checks available balance; locked funds are only accessible via the bet they are committed to
- **Expired bets are always recoverable** — `claimTimeout` is permissionless; anyone (including keeper bots) can trigger it once the deadline passes

### Trust assumptions

- **Multisig integrity** — `ShakeOnIt` is owned by a multisig. A compromised multisig can upgrade `BetRegistry` to a malicious implementation. Mitigated by using a genuine multi-party multisig and, for production deployments, adding a timelock to `upgradeBetRegistry`.
- **Arbiter honesty** — The arbiter has unilateral power to declare the winner before the deadline. Participants must select arbiters they trust. There is no on-chain dispute layer.
- **Standard ERC-20 tokens only** — Fee-on-transfer and rebasing tokens will cause accounting drift if allowlisted. Only standard ERC-20 tokens should ever be added to the vault allowlist.

---

## Events & Off-Chain Indexing

Every event is self-contained — no additional contract call is needed to reconstruct what happened from the log alone. No arrays of bets or users are stored on-chain; all historical data is reconstructed from events using an indexer such as The Graph.

| Contract | Event | Parameters |
|---|---|---|
| `UserVault` | `Deposited` | `indexed user, indexed token, amount` |
| `UserVault` | `Withdrawn` | `indexed user, indexed token, amount` |
| `UserVault` | `Locked / Unlocked / Debited / Credited` | `indexed user, indexed token, amount` |
| `UserVault` | `TokenAllowlistUpdated` | `indexed token, allowed` |
| `UserRegistry` | `UserRegistered` | `indexed user, indexed username` |
| `UserRegistry` | `WinRecorded / LossRecorded` | `indexed user, totalWins/totalLosses` |
| `BetRegistry` | `BetCreated` | `indexed betId, indexed creator, indexed arbiter, token, stake, arbiterFee, platformFee, deadline, betType` |
| `BetRegistry` | `BetMatched` | `indexed betId, indexed challenger, token, stake` |
| `BetRegistry` | `BetSettled` | `indexed betId, indexed winner, indexed loser, token, payout, arbiterFee, platformFee` |
| `BetRegistry` | `BetCancelled` | `indexed betId, indexed creator, token, stake` |
| `BetRegistry` | `BetForfeited` | `indexed betId, indexed forfeiter, indexed winner, token, payout, platformFee` |
| `BetRegistry` | `BetRefunded` | `indexed betId, indexed creator, indexed challenger, token, refundPerParticipant, platformFee` |
| `ShakeOnIt` | `SystemDeployed` | `indexed vault, indexed registry, indexed betRegistry, platformAddress` |
| `ShakeOnIt` | `BetRegistryUpgraded` | `indexed oldRegistry, indexed newRegistry` |

---

## Subgraph

A Graph Protocol subgraph is included at `subgraph/` for indexing all contract events into a queryable GraphQL API.

### Entities

| Entity | Description |
|---|---|
| `Bet` | Full bet state — status, participants, fees, timestamps |
| `User` | Per-address profile — wins, losses, total wagered, total earned |
| `UserTokenBalance` | Available and locked balance per (user, token) pair |
| `Platform` | Singleton — total bets, active bets, lifetime fees, outcome breakdown |
| `DailyStats` | Daily aggregates for charts — volume, fees, bet outcomes |

### Example queries

```graphql
# Platform overview
{
  platform(id: "platform") {
    totalBets
    activeBets
    totalFeesCollected
    totalSettled
    totalTimedOut
  }
}

# User profile and bet history
{
  user(id: "0xabc...") {
    wins
    losses
    totalWagered
    totalEarned
    betsCreated { id status deadline }
    balances { token available locked }
  }
}

# Daily fee revenue for the last 30 days
{
  dailyStats(orderBy: date, orderDirection: desc, first: 30) {
    date
    feesCollected
    betsSettled
    betsTimedOut
  }
}

# All currently active bets
{
  bets(where: { status: "MATCHED" }, orderBy: deadline, orderDirection: asc) {
    id
    creator { id }
    challenger { id }
    arbiter
    stake
    deadline
  }
}
```

### Deploying the subgraph

1. Deploy contracts and note the block number
2. Update the three `address` fields and `startBlock` values in `subgraph/subgraph.yaml`
3. Create a subgraph on [thegraph.com/studio](https://thegraph.com/studio)
4. Run:

```bash
cd subgraph
npx graph codegen
npx graph build
npx graph deploy <your-subgraph-slug>
```

---

## Local Development

**Prerequisites:** Node.js 18+, npm

```bash
# Install dependencies
npm install --legacy-peer-deps

# Compile contracts
npx hardhat compile

# Run all tests
npx hardhat test

# Run coverage
npx hardhat coverage --testfiles "test/userVault.test.js,test/userRegistry.test.js,test/betRegistry.test.js,test/shakeOnIt.test.js"
```

### Test coverage

| Contract | Statements | Branches | Functions | Lines |
|---|---|---|---|---|
| `BetRegistry.sol` | 100% | 96.25% | 100% | 100% |
| `ShakeOnIt.sol` | 100% | 100% | 100% | 100% |
| `UserRegistry.sol` | 100% | 100% | 100% | 100% |
| `UserVault.sol` | 100% | 84.62% | 100% | 100% |

---

## Deployment

The entire system is deployed by deploying `ShakeOnIt` alone. It handles everything else internally.

```bash
# Local
npx hardhat run scripts/deploy.js

# Base Sepolia testnet
MULTISIG_ADDRESS=0x... PLATFORM_ADDRESS=0x... npx hardhat run scripts/deploy.js --network base-sepolia
```

**Environment variables**

| Variable | Required | Description |
|---|---|---|
| `MULTISIG_ADDRESS` | Yes (non-local) | Address that will own `ShakeOnIt` |
| `PLATFORM_ADDRESS` | Yes (non-local) | Address that receives platform fees |
| `ALLOWED_TOKENS` | No | Comma-separated token addresses to allowlist on deploy |
| `WALLET_KEY` | Yes (non-local) | Private key of the deploying wallet |

**Post-deploy checklist**

1. Confirm `ShakeOnIt.owner()` is the intended multisig
2. Add tokens via `shakeOnIt.setTokenAllowed(tokenAddress, true)` from the multisig
3. Update `subgraph/subgraph.yaml` with deployed addresses and start block, then deploy the subgraph
4. Share `UserRegistry` address so users can call `register(username)`
5. Share `UserVault` address so users can `deposit` and `withdraw`
6. Share `BetRegistry` address so users can `createBet` and `acceptBet`

---

## Testnet Contracts

### Base Sepolia (legacy v1)

> These are the original contract deployments and use the old architecture. They will be superseded when the v2 system is deployed.

| Contract | Address |
|---|---|
| UserManagement | `0x7f68AAE9C9cB52E4689763F9Ef2c859778578230` |
| BetManagement | `0x021b140B5F931237eD6934B539dE57c111584754` |
| DataCenter | `0x934726B886D24fdD98701aF57BedcBCd137870FF` |
| Vbux | `0x9D2A5b0B86a630333eBC02E3cd080Dc60Fe583F9` |
