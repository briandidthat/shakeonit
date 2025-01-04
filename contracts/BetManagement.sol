// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./UserManagement.sol";
import "./Restricted.sol";

contract BetManagement is IShakeOnIt, Restricted {
    address private multiSig;
    address[] public deployedBets;
    mapping(address => bool) public isBet;

    event BetCreated(
        address indexed betAddress,
        address indexed initiator,
        address indexed arbiter,
        address token,
        uint256 stake,
        string condition
    );

    event BetAccepted(
        address indexed betAddress,
        address indexed acceptor,
        address indexed token,
        uint256 stake
    );

    event BetWon(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        address token,
        uint256 stake
    );

    event BetSettled(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        address token,
        uint256 stake
    );

    event BetCancelled(address indexed betAddress, address indexed initiator);

    constructor(address _multiSig) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
        // set the multiSig address
        multiSig = _multiSig;
    }

    /**
     * @notice Deploys a new bet contract.
     * @param _token The address of the token to be used for the bet.
     * @param _initiator The address of the initiator of the bet.
     * @param _arbiter The address of the arbiter of the bet.
     * @param _amount The stake of the bet.
     * @param _arbiterFee The fee to be paid to the arbiter.
     * @param _platformFee The fee to be paid to the platform.
     * @param _payout The payout stake.
     * @param _condition The condition of the bet.
     * @return The address of the deployed bet contract.
     */
    function deployBet(
        address _token,
        UserDetails memory _initiator,
        UserDetails memory _arbiter,
        uint256 _amount,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _payout,
        string memory _condition
    ) external returns (address) {
        require(_amount > 0, "Amount should be greater than 0");
        require(
            _initiator.storageAddress != address(0) &&
                _arbiter.storageAddress != address(0),
            "Zero address not allowed"
        );

        // Deploy a new bet contract
        Bet bet = new Bet(
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

        // transfer the stake to the bet contract
        require(
            IERC20(_token).transferFrom(
                _initiator.storageAddress,
                betAddress,
                _amount
            ),
            "Token transfer failed"
        );

        // update the state
        deployedBets.push(betAddress);
        isBet[betAddress] = true;
        // grant the bet contract the BET_CONTRACT_ROLE
        _grantRole(BET_CONTRACT_ROLE, betAddress);
        // save the bet in the initiator's and arbiter's storage
        UserStorage(_initiator.storageAddress).saveBet(_betDetails);
        UserStorage(_arbiter.storageAddress).saveBet(_betDetails);
        // emit BetCreated event
        emit BetCreated(
            _betDetails.betContract,
            _betDetails.initiator.storageAddress,
            _betDetails.arbiter.storageAddress,
            _betDetails.token,
            _betDetails.stake,
            _condition
        );

        return betAddress;
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) returns (bool) {
        // fund the bet contract
        require(
            IERC20(_betDetails.token).transferFrom(
                _betDetails.acceptor.storageAddress,
                _betDetails.betContract,
                _betDetails.stake
            ),
            "Token transfer failed"
        );
        // update the bet for all parties
        UserStorage(_betDetails.initiator.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.acceptor.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.arbiter.storageAddress).saveBet(_betDetails);
        // emit BetAccepted event
        emit BetAccepted(
            _betDetails.betContract,
            _betDetails.acceptor.storageAddress,
            _betDetails.token,
            _betDetails.stake
        );
        return true;
    }

    /**
     * @notice Declares the winner of the bet and transfers the funds to the winner.
     */
    function reportWinnerDeclared(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) {
        // update the bet for all parties
        UserStorage(_betDetails.initiator.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.acceptor.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.arbiter.storageAddress).saveBet(_betDetails);
        // emit BetWon event
        emit BetWon(
            _betDetails.betContract,
            _betDetails.winner,
            _betDetails.arbiter.storageAddress,
            _betDetails.token,
            _betDetails.stake
        );
    }

    function reportBetSettled(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) {
        // update the bet for all parties
        UserStorage(_betDetails.initiator.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.acceptor.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.arbiter.storageAddress).saveBet(_betDetails);
        // remove the BET_CONTRACT_ROLE from the bet contract
        _revokeRole(BET_CONTRACT_ROLE, _betDetails.betContract);
        // emit BetSettled event
        emit BetSettled(
            _betDetails.betContract,
            _betDetails.winner,
            _betDetails.loser,
            _betDetails.token,
            _betDetails.stake
        );
    }

    /**
     * @notice Cancels the bet and updates the state.
     */
    function reportCancellation(
        BetDetails memory _betDetails
    ) external onlyRole(BET_CONTRACT_ROLE) {
        // update the bet for initiator and arbiter (acceptor is not updated atp)
        UserStorage(_betDetails.initiator.storageAddress).saveBet(_betDetails);
        UserStorage(_betDetails.arbiter.storageAddress).saveBet(_betDetails);
        // remove the BET_CONTRACT_ROLE from the bet contract
        _revokeRole(BET_CONTRACT_ROLE, _betDetails.betContract);
        // emit BetCancelled event
        emit BetCancelled(msg.sender, _betDetails.betContract);
    }

    function getMultiSig() external view returns (address) {
        return multiSig;
    }

    function getBets() external view returns (address[] memory) {
        return deployedBets;
    }

    function getBetCount() external view returns (uint256) {
        return deployedBets.length;
    }
}
