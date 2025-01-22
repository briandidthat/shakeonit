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
        uint256 stake
    );

    event BetCancelled(address indexed betAddress, address indexed initiator);
    event BetAccepted(address indexed betAddress, address indexed acceptor);
    event BetWon(
        address indexed betAddress,
        uint256 arbiterFee,
        uint256 platformFee
    );
    event BetSettled(
        address indexed betAddress,
        address indexed token,
        uint256 payout
    );

    constructor(address _multiSig) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
        // set the multiSig address
        multiSig = _multiSig;
    }

    /**
     * @notice Deploys a new bet contract and initializes it with the given parameters
     * @dev Transfers the stake from initiator to the new bet contract and updates related states
     * @param _token Address of the ERC20 token to be used for the bet
     * @param _initiator Struct containing initiator's address including their storage address
     * @param _arbiter Struct containing arbiter's address including their storage address
     * @param _stake Amount of tokens to be staked in the bet
     * @param _arbiterFee Fee to be paid to the arbiter
     * @param _platformFee Fee to be paid to the platform
     * @param _payout Total payout amount for the bet (stake * 2 - (arbiterFee + platformFee))
     * @param _condition String describing the conditions of the bet
     * @return address The address of the newly deployed bet contract
     * @custom:throws "Amount should be greater than 0" if stake is 0
     * @custom:throws "Zero address not allowed" if initiator or arbiter address is zero
     * @custom:throws "Insufficient balance" if initiator storage address does not have enough tokens
     * @custom:throws "Insufficient allowance" if initiiatior storage address does have enough allowance
     * @custom:throws "Token transfer failed" if the token transfer fails
     * @custom:emits BetCreated event with bet details
     */
    function deployBet(
        address _token,
        UserDetails memory _initiator,
        UserDetails memory _arbiter,
        uint256 _stake,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _payout,
        string memory _condition
    ) external returns (address) {
        require(_stake > 0, "Amount should be greater than 0");
        require(
            _initiator.storageAddress != address(0) &&
                _arbiter.storageAddress != address(0),
            "Zero address not allowed"
        );
        require(
            IERC20(_token).balanceOf(_initiator.storageAddress) >= _stake,
            "Insufficient balance"
        );
        require(
            IERC20(_token).allowance(
                _initiator.storageAddress,
                address(this)
            ) >= _stake,
            "Insufficient allowance"
        );

        // Deploy a new bet contract
        Bet bet = new Bet(
            _token,
            _initiator,
            _arbiter,
            _stake,
            _arbiterFee,
            _platformFee,
            _payout,
            _condition
        );
        address betAddress = address(bet);

        // transfer the stake to the bet contract
        require(
            IERC20(_token).transferFrom(
                _initiator.storageAddress,
                betAddress,
                _stake
            ),
            "Token transfer failed"
        );

        // update balance after successful transfer
        bet.updateBalance(_token, _stake);

        // update the state
        isBet[betAddress] = true;
        deployedBets.push(betAddress);
        // grant the bet contract the BET_CONTRACT_ROLE
        _grantRole(BET_CONTRACT_ROLE, betAddress);
        // save the bet in the initiator's and arbiter's storage
        BetDetails memory betDetails = bet.getBetDetails();
        UserStorage(_initiator.storageAddress).saveBet(betDetails);
        UserStorage(_arbiter.storageAddress).saveBet(betDetails);
        // emit BetCreated event
        emit BetCreated(
            betAddress,
            _initiator.storageAddress,
            _arbiter.storageAddress,
            _token,
            _stake
        );

        return betAddress;
    }

    /**
     * @notice Accepts the bet and funds the escrow.
     */
    function acceptBet() external hasCorrectRole(BET_CONTRACT_ROLE) {
        BetDetails memory betDetails = Bet(msg.sender).getBetDetails();
        // fund the bet contract
        require(
            IERC20(betDetails.token).transferFrom(
                betDetails.acceptor.storageAddress,
                betDetails.betContract,
                betDetails.stake
            ),
            "Token transfer failed"
        );
        // update the bet for all parties
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.acceptor.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // emit BetAccepted event
        emit BetAccepted(msg.sender, betDetails.acceptor.storageAddress);
    }

    /**
     * @notice Declares the winner of the bet and transfers the funds to the winner.
     */
    function reportWinnerDeclared() external hasCorrectRole(BET_CONTRACT_ROLE) {
        BetDetails memory betDetails = Bet(msg.sender).getBetDetails();
        // update the bet for all parties (msg.sender will be the contract address)
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.acceptor.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // emit BetWon event
        emit BetWon(msg.sender, betDetails.arbiterFee, betDetails.platformFee);
    }

    function reportBetSettled() external hasCorrectRole(BET_CONTRACT_ROLE) {
        BetDetails memory betDetails = Bet(msg.sender).getBetDetails();
        // update the bet for all parties (msg.sender will be the contract address)
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.acceptor.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // remove the BET_CONTRACT_ROLE from the bet contract
        _revokeRole(BET_CONTRACT_ROLE, msg.sender);
        // emit BetSettled event
        emit BetSettled(msg.sender, betDetails.token, betDetails.payout);
    }

    /**
     * @notice Cancels the bet and updates the state.
     */
    function reportCancellation() external hasCorrectRole(BET_CONTRACT_ROLE) {
        BetDetails memory betDetails = Bet(msg.sender).getBetDetails();
        // update the bet for initiator and arbiter (acceptor is not updated atp)
        UserStorage(betDetails.initiator.storageAddress).saveBet(betDetails);
        UserStorage(betDetails.arbiter.storageAddress).saveBet(betDetails);
        // remove the BET_CONTRACT_ROLE from the bet contract
        _revokeRole(BET_CONTRACT_ROLE, msg.sender);
        // emit BetCancelled event
        emit BetCancelled(msg.sender, betDetails.initiator.storageAddress);
    }

    function setNewMultiSig(
        address _newMultiSig
    ) external onlyRole(MULTISIG_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, _newMultiSig);
        _grantRole(MULTISIG_ROLE, _newMultiSig);
        _revokeRole(MULTISIG_ROLE, msg.sender);

        multiSig = _newMultiSig;
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
