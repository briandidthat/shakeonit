# ShakeOnIt

ShakeOnIt is a decentralized application (dApp) that facilitates the creation and management of bets between users. The project leverages smart contracts on the Ethereum blockchain to ensure transparency, security, and immutability of the betting process. The system includes user management, arbiter management, and bet management functionalities, all orchestrated by a central `DataCenter` contract.

## Project Structure

The project is divided into several smart contracts, each responsible for a specific aspect of the system. Below is a detailed explanation of each contract and its purpose.

### Contracts

#### DataCenter.sol

The `DataCenter` contract acts as the central hub for the ShakeOnIt system. It manages the interactions between users, arbiters, and bets. The contract is responsible for:

- Managing the multi-signature wallet address.
- Interfacing with the `UserManagement`, `ArbiterManagement`, and `BetManagement` contracts.
- Facilitating the creation and management of bets.
- Registering users and arbiters.

**Key Functions:**
- `setNewMultiSig(address _newMultiSig)`: Updates the multi-signature wallet address.
- `createBet(BetLibrary.BetDetails memory _betDetails)`: Creates a new bet.
- `addUser(address _user)`: Adds a new user.
- `blockArbiter(address _arbiter, string memory _reason)`: Blocks an arbiter.
- `addArbiter(address _arbiter)`: Adds a new arbiter.
- `getMultiSig()`: Returns the multi-signature wallet address.
- `getUserManagement()`: Returns the address of the `UserManagement` contract.
- `getArbiterManagement()`: Returns the address of the `ArbiterManagement` contract.
- `getBetManagement()`: Returns the address of the `BetManagement` contract.
- `getBetFactory()`: Returns the address of the bet factory.

#### UserManagement.sol

The `UserManagement` contract handles the registration and management of users within the ShakeOnIt system. It ensures that each user has a corresponding `UserStorage` contract to store their bets.

**Key Functions:**
- `addUser(address _user)`: Registers a new user and creates a `UserStorage` contract for them.
- `getUserStorage(address _user)`: Returns the address of the user's `UserStorage` contract.
- `getUsers()`: Returns a list of all registered users.

#### ArbiterManagement.sol

The `ArbiterManagement` contract manages arbiters who are responsible for resolving disputes between users. It allows for the addition, suspension, and blocking of arbiters.

**Key Functions:**
- `addArbiter(address _arbiter)`: Registers a new arbiter.
- `suspendArbiter(address _arbiter, string memory _reason)`: Suspends an arbiter.
- `blockArbiter(address _arbiter, string memory _reason)`: Blocks an arbiter.
- `getArbiters()`: Returns a list of all registered arbiters.
- `getBlockedArbiters()`: Returns a list of all blocked arbiters.
- `getArbiter(address _arbiter)`: Returns the address of the arbiter's contract.
- `isRegistered(address _arbiter)`: Checks if an address is registered as an arbiter.

#### BetManagement.sol

The `BetManagement` contract handles the creation and management of bets. It stores the details of each bet and ensures that all bets are properly tracked and managed.

**Key Functions:**
- `createBet(BetLibrary.BetDetails memory _betDetails, address userStorageAddress)`: Creates a new bet and stores it in the user's `UserStorage` contract.
- `getBets()`: Returns a list of all created bets.

#### UserStorage.sol

The `UserStorage` contract is deployed for each user and stores the details of all bets they are involved in. It ensures that users can easily track their betting history.

**Key Functions:**
- `addBet(address _bet)`: Adds a new bet to the user's storage.
- `getBets()`: Returns a list of all bets stored in the contract.

#### Arbiter.sol

The `Arbiter` contract represents an arbiter in the system. It includes functionalities for managing the arbiter's status and handling penalties.

**Key Functions:**
- `suspend(string memory _reason)`: Suspends the arbiter. Can only be called by the multisig
- `block(string memory _reason)`: Blocks the arbiter.
- `penalize(address _token, uint256 _amount)`: Penalizes the arbiter by transferring tokens.


**Key Structures:**
- `struct BetDetails`: Defines the details of a bet.
- `enum BetStatus`: Defines the possible statuses of a bet (INITIATED, FUNDED, WON, SETTLED, CANCELLED).
