// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Bet is IShakeOnIt, Initializable {
    address public dataCenter;
    address public initiator;
    address public acceptor;
    address public arbiter;
    address public winner;
    uint256 public amount;
    uint256 public payout;
    uint256 public arbiterFee;
    uint256 public platformFee;
    uint256 public deadline;
    string public condition;
    IERC20 public fundToken;
    BetStatus public status;
    mapping(address => uint256) public balances;

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Restricted to arbiter");
        _;
    }

    modifier onlyParties() {
        require(
            msg.sender == initiator || msg.sender == acceptor,
            "Restricted to bet participants"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _dataCenter,
        address _initiator,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _arbiterFee,
        uint256 _platformFee,
        uint256 _deadline,
        string memory _condition
    ) external initializer {
        require(
            fundToken.transferFrom(_initiator, address(this), _amount),
            "Token transfer failed"
        );
        // update the balance of the initiator upon successful transfer
        balances[_initiator] = _amount;

        dataCenter = _dataCenter;
        initiator = _initiator;
        arbiter = _arbiter;
        fundToken = IERC20(_fundToken);
        amount = _amount;
        arbiterFee = _arbiterFee;
        platformFee = _platformFee;
        payout = amount - (arbiterFee + platformFee);
        deadline = _deadline;
        condition = _condition;
        status = BetStatus.INITIATED;
    }

    function acceptBet() external {
        require(status == BetStatus.INITIATED, "Bet must be in initiated status");
        require(
            balances[msg.sender] == 0,
            "Participant has already funded the escrow"
        );
        require(
            fundToken.transferFrom(msg.sender, address(this), amount),
            "Token transfer failed"
        );

        // update the balance of the acceptor
        acceptor = msg.sender;
        balances[msg.sender] = amount;
        status = BetStatus.FUNDED;
    }

    /**
     * @notice Declares the winner of the bet.
     * @dev This function can only be called by the arbiter.
     * @param _winner The address of the participant who is declared the winner.
     */
    function declareWinner(address _winner) external onlyArbiter {
        require(_winner == initiator || _winner == acceptor, "Invalid winner"); // ensure the winner is a participant
        require(status == BetStatus.FUNDED, "Bet has not been funded yet"); // ensure the bet is funded
        require(block.timestamp >= deadline, "Deadline has not passed yet"); // ensure the deadline has passed
        
        // update the winner
        winner = _winner;
        // update the status of the bet
        status = BetStatus.WON;

        // transfer the funds to the arbiter
        IERC20 token = IERC20(address(fundToken));
        require(
            token.transfer(arbiter, arbiterFee),
            "Token transfer to arbiter failed"
        );

        emit BetWon(address(this), winner, arbiter, address(fundToken), amount);
    }

    function withdrawEarnings() external onlyParties {
        require(msg.sender == winner, "Restricted to winner");
        require(status == BetStatus.WON, "Bet has not been declared won yet");
        require(balances[msg.sender] > 0, "No funds to withdraw");

        // transfer the platform fee to the factory
        require(
            fundToken.transfer(dataCenter, platformFee),
            "Token transfer failed"
        );

        // transfer the funds to the winner
        require(
            fundToken.transfer(msg.sender, payout),
            "Token transfer failed"
        );
        // update the balance of the participant
        balances[msg.sender] = 0;
        // update the status of the bet
        status = BetStatus.SETTLED;

        emit BetSettled(
            address(this),
            msg.sender,
            arbiter,
            address(fundToken),
            amount
        );
    }
}
