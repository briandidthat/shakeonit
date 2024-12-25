// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./Bet.sol";
import "./BetManagement.sol";
import "./DataCenter.sol";
import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BetFactory is Ownable, IShakeOnIt {
    uint256 private instances;
    DataCenter private dataCenter;

    constructor(address _dataCenter) Ownable(msg.sender) {
        dataCenter = DataCenter(_dataCenter);
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
        uint256 _payout,
        uint256 _deadline,
        string memory _condition
    ) external returns (address) {
        require(dataCenter.isUser(msg.sender), "User has not registered");
        require(_amount > 0, "Amount should be greater than 0");
        require(
            msg.sender != address(0) && _arbiter != address(0),
            "Zero address not allowed"
        );

        // get the user storage address
        address userStorageAddress = dataCenter.getUserStorage(msg.sender);
        // check if the user has sufficient balance for the bet amount
        require(
            IERC20(_fundToken).balanceOf(userStorageAddress) >= _amount,
            "Insufficient balance"
        );

        // Deploy a new bet contract
        Bet bet = new Bet(
            address(dataCenter),
            userStorageAddress,
            _arbiter,
            _fundToken,
            _amount,
            _payout,
            _deadline,
            _arbiterFee,
            _platformFee,
            _condition
        );

        // create bet details for storage
        BetDetails memory betDetails = BetDetails({
            betContract: address(bet),
            initiator: userStorageAddress,
            acceptor: address(0),
            arbiter: _arbiter,
            winner: address(0),
            loser: address(0),
            fundToken: _fundToken,
            amount: _amount,
            payout: _payout,
            deadline: _deadline,
            status: BetStatus.INITIATED
        });

        // get the BetManagement contract
        address betManagementAddress = dataCenter.getBetManagement();
        BetManagement betManagement = BetManagement(betManagementAddress);
        // store the bet details in the bet management contract
        betManagement.createBet(betDetails);
        // increment the number of instances
        instances++;
        // return the address of the bet
        return address(bet);
    }
}
