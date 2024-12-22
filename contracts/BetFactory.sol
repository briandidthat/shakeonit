// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./Bet.sol";
import "./interfaces/IShakeOnIt.sol";
import "./DataCenter.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BetFactory is Ownable, IShakeOnIt {
    address private implementation;
    address private multiSigWallet;
    uint256 private platformPercentage;
    uint256 private instances;
    DataCenter private dataCenter;

    constructor(
        address _multiSig,
        uint256 _platformPercentage
    ) Ownable(msg.sender) {
        implementation = address(new Bet());
        multiSigWallet = _multiSig;
        platformPercentage = _platformPercentage;
        dataCenter = new DataCenter(address(this));
    }

    /**
     * @dev Deploy a new bet
     * @param _arbiter The address of the arbiter
     * @param _fundToken The address of the token to be used for the bet
     * @param _amount The amount to be deposited to the bet contract
     * @param _deadline The deadline for the bet
     * @param _condition The condition of the bet
     */
    function deployBet(
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _deadline,
        string memory _condition
    ) external returns (address) {
        require(_amount > 0, "Amount should be greater than 0");
        require(
            msg.sender != address(0) && _arbiter != address(0),
            "Zero address not allowed"
        );
        // get the user storage address
        address userStorageAddress = dataCenter.getUserStorage(msg.sender);
        require(userStorageAddress != address(0), "User has not registered");
        require(
            IERC20(_fundToken).balanceOf(userStorageAddress) >= _amount,
            "Insufficient balance"
        );

        // Create a new bet clone
        address bet = Clones.clone(implementation);
        // Initialize the bet clone
        Bet(bet).initialize(
            multiSigWallet,
            address(dataCenter),
            msg.sender,
            _arbiter,
            _fundToken,
            _amount,
            _deadline,
            _arbiterFee,
            _platformFee,
            _condition
        );

        // increment the number of instances
        instances++;

        // create bet details
        BetDetails memory betDetails = BetDetails({
            betContract: bet,
            initiator: msg.sender,
            acceptor: address(0),
            arbiter: _arbiter,
            winner: address(0),
            loser: address(0),
            fundToken: _fundToken,
            amount: _amount,
            deadline: _deadline,
            accepted: false,
            message: _condition,
            status: BetStatus.INITIATED
        });

        // store the bet details in the data center
        dataCenter.createBet(betDetails);
        // return the address of the bet
        return bet;
    }

    function register() external returns (address) {
        // add a new user in the data center
        address userStorage = dataCenter.addUser(msg.sender);
        return userStorage;
    }

    function getImplementation() external view returns (address) {
        return implementation;
    }

    function getPlatformPercentage() external view returns (uint256) {
        return platformPercentage;
    }
}
