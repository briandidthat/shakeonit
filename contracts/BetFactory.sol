// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./Bet.sol";
import "./DataCenter.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BetFactory is Ownable {
    address public implementation;
    uint256 public instances;
    DataCenter private dataCenter;

    event BetCreated(
        address indexed betAddress,
        address indexed initiator,
        address indexed arbiter,
        address fundToken,
        uint256 amount,
        uint256 deadline
    );

    event BetAccepted(
        address indexed betAddress,
        address indexed acceptor,
        address indexed fundToken,
        uint256 amount,
        uint256 deadline
    );

    constructor(address _dataCenter) {
        implementation = address(new Bet());
        dataCenter = DataCenter(_dataCenter);
    }

    /**
     * @dev Create a new bet
     * @param _initiator The address of the user creating the bet
     * @param _arbiter The address of the arbiter
     * @param _fundToken The address of the token to be used for the bet
     * @param _amount The amount to be deposited to the bet contract
     * @param _deadline The deadline for the bet
     * @param _condition The condition of the bet
     */
    function createBet(
        address _initiator,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _condition
    ) external {
        require(_amount > 0, "Amount should be greater than 0");
        require(
            _initiator != address(0) && _arbiter != address(0),
            "Zero address not allowed"
        );
        require(
            IERC20(_fundToken).balanceOf(_proposer) >= _amount,
            "Insufficient balance"
        );

        // Create a new bet clone
        address bet = Clones.clone(implementation);
        // Initialize the bet clone
        Bet(bet).initialize(
            msg.sender,
            _arbiter,
            _fundToken,
            _amount,
            _deadline,
            _condition
        );

        // increment the number of instances
        instances++;
        // store the proposal in the data center
        dataCenter.createBet(
            bet,
            msg.sender,
            _arbiter,
            _fundToken,
            _amount,
            _deadline,
            _condition
        );

        // emit an event
        emit BetCreated(
            bet,
            msg.sender,
            _arbiter,
            _fundToken,
            _amount,
            _deadline
        );

        return bet;
    }
}
