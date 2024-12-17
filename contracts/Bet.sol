// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Bet is IShakeOnIt, Initializable {
    address public initiator;
    address public acceptor;
    address public arbiter;
    uint256 public amount;
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
        address _initiator,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
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

    function declareWinner(address winner) external onlyArbiter {
        require(status == BetStatus.FUNDED, "Bet not funded yet"); // ensure the bet is funded
        require(winner == initiator || winner == acceptor, "Invalid winner"); // ensure the winner is a participant
        require(block.timestamp >= deadline, "Bet has expired"); // ensure the deadline has passed

        status = BetStatus.WON;
    }
}
