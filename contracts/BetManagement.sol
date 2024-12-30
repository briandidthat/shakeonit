// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./BetStorage.sol";
import "./UserManagement.sol";
import "./Restricted.sol";

contract BetManagement is IShakeOnIt, Restricted {
    address[] public deployedBets;
    BetStorage private betStorage;
    mapping(address => bool) public isBet;

    constructor(address _multiSig) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
        // create a new BetStorage contract
        betStorage = new BetStorage(_multiSig, address(this));
    }

    /**
     * @notice Deploys a new bet contract.
     * @param _token The address of the token to be used for the bet.
     * @param _initiator The address of the initiator of the bet.
     * @param _arbiter The address of the arbiter of the bet.
     * @param _amount The amount of the bet.
     * @param _arbiterFee The fee to be paid to the arbiter.
     * @param _platformFee The fee to be paid to the platform.
     * @param _payout The payout amount.
     * @param _condition The condition of the bet.
     * @return The address of the deployed bet contract.
     */
    function deployBet(
        address _token,
        address _initiator,
        address _arbiter,
        uint256 _amount,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _payout,
        string memory _condition
    ) external returns (address) {
        require(_amount > 0, "Amount should be greater than 0");
        require(
            _initiator != address(0) && _arbiter != address(0),
            "Zero address not allowed"
        );

        // Deploy a new bet contract
        Bet bet = new Bet(
            address(this),
            _token,
            _initiator,
            _arbiter,
            _amount,
            _arbiterFee,
            _platformFee,
            _payout,
            _condition
        );
        address betAddress = address(bet);
        BetDetails memory _betDetails = bet.getBetDetails();

        // transfer the amount to the bet contract
        require(
            IERC20(_token).transferFrom(_initiator, betAddress, _amount),
            "Token transfer failed"
        );

        // update the state
        deployedBets.push(betAddress);
        isBet[betAddress] = true;
        // grant the bet contract the BET_CONTRACT_ROLE
        _grantRole(BET_CONTRACT_ROLE, betAddress);
        // save the bet details in the bet storage
        betStorage.createBet(_betDetails);

        // emit BetCreated event
        emit BetCreated(
            _betDetails.betContract,
            _betDetails.initiator,
            _betDetails.arbiter,
            _betDetails.token,
            _betDetails.amount,
            _condition
        );

        return betAddress;
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) {
        betStorage.acceptBet(_betDetails);

        // emit BetAccepted event
        emit BetAccepted(
            _betDetails.betContract,
            _betDetails.acceptor,
            _betDetails.token,
            _betDetails.amount
        );
    }

    /**
     * @notice Declares the winner of the bet and transfers the funds to the winner.
     */
    function declareWinner(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) {
        betStorage.declareWinner(_betDetails);
        // emit BetWon event
        emit BetWon(
            _betDetails.betContract,
            _betDetails.winner,
            _betDetails.arbiter,
            _betDetails.token,
            _betDetails.amount
        );
    }

    /**
     * @notice Cancels the bet and updates the state.
     */
    function cancelBet(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) {
        // update the state of the bet
        betStorage.cancelBet(_betDetails);
        // emit BetCancelled event
        emit BetCancelled(msg.sender, _betDetails.betContract);
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getUserBets(
        address _user
    ) external view returns (address[] memory) {
        return betStorage.getUserBets(_user);
    }
}
