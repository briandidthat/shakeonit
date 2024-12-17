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
    uint256 public deadline;
    uint256 public arbiterPercentage;
    uint256 public arbiterFee;
    uint256 public platformFee;
    uint256 public platformPercentage;
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
        uint256 _deadline,
        uint256 _arbiterPercentage,
        uint256 _platformPercentage,
        string memory _condition
    ) external initializer {
        require(
            fundToken.transferFrom(_initiator, address(this), _amount),
            "Token transfer failed"
        );
        // update the balance of the initiator upon successful transfer
        balances[_initiator] = _amount;

        initiator = _initiator;
        arbiter = _arbiter;
        fundToken = IERC20(_fundToken);
        amount = _amount;
        deadline = _deadline;
        arbiterPercentage = _arbiterPercentage;
        platformPercentage = _platformPercentage;
        condition = _condition;
        status = BetStatus.INITIATED;
    }

    function acceptBet(uint256 _amount, address _token) external {
        require(
            _token == address(fundToken),
            "Token sent must be the same as the escrow token"
        );
        require(
            balances[msg.sender] == 0,
            "Participant has already funded the escrow"
        );
        require(status != BetStatus.FUNDED, "Bet is already funded");

        IERC20 token = IERC20(_token);

        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        // update the balance of the acceptor
        acceptor = msg.sender;
        balances[msg.sender] = _amount;
        status = BetStatus.FUNDED;
    }

    /**
     * @notice Declares the winner of the bet.
     * @dev This function can only be called by the arbiter.
     * @param _winner The address of the participant who is declared the winner.
     */
    function declareWinner(address _winner) external onlyArbiter {
        require(status == BetStatus.FUNDED, "Bet not funded yet"); // ensure the bet is funded
        require(_winner == initiator || _winner == acceptor, "Invalid winner"); // ensure the winner is a participant
        require(block.timestamp >= deadline, "Bet has expired"); // ensure the deadline has passed
        // update the status of the bet
        status = BetStatus.WON;

        // update the winner
        winner = _winner;

        // calculate the arbiter and platform fees
        arbiterFee = (amount * arbiterPercentage) / 100;
        platformFee = (amount * platformPercentage) / 100;

        // calculate the final payout for the winner
        payout = amount - (arbiterFee + platformFee);

        // transfer the funds to the arbiter
        IERC20 token = IERC20(address(fundToken));
        require(
            token.transfer(arbiter, arbiterFee),
            "Token transfer to arbiter failed"
        );
    }

    function withdrawEarnings() external onlyParties {
        require(msg.sender == winner, "Restricted to winner");
        require(status == BetStatus.WON, "Bet not won yet");
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
