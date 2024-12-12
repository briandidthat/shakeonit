// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.0;

import "./interfaces/IERC20.sol";

contract Bet {
    enum Status { PENDING, FUNDED, SETTLED }

    address public partyA;
    address public partyB;
    address public arbiter;
    IERC20 public fundToken;
    uint256 public amount;
    uint256 public deadline;
    bool public partyAPaid;
    bool public partyBPaid;
    bool public active;
    bool public payoutComplete;
    bool public canPayBeforeDeadline;
    Status public status;
    mapping(address => uint256) public balances;

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Restricted to arbiter");
        _;
    }

    modifier onlyParties() {
        require(
            msg.sender == partyA || msg.sender == partyB,
            "Restricted to escrow participants"
        );
        _;
    }

    constructor(
        address _partyA,
        address _partyB,
        address _arbiter,
        address _fundToken,
        uint _amount
    ) {
        partyA = _partyA;
        partyB = _partyB;
        arbiter = _arbiter;
        fundToken = IERC20(_fundToken);
        amount = _amount;
    }

    function fund() external payable onlyParties {
        require(
            msg.value == amount,
            "Amount sent must be equal to escrow amount"
        );
        if (msg.sender == partyA) {
            partyAPaid = true;
        } else {
            partyBPaid = true;
        }

        if (partyAPaid && partyBPaid) {
            active = true;
        }
    }

    /**
     * @dev Fund the escrow with ERC20 tokens
     * @param _amount The amount of tokens to fund the escrow
     * @param _token The address of the token to fund the escrow
     * @param party The address of the party funding the escrow
     */
    function fund(uint256 _amount, address _token, address party) external onlyParties {
        require(
            _token == address(fundToken),
            "Token sent must be the same as the escrow token"
        )
        require(
            msg.value == _amount,
            "Amount sent must be equal to escrow amount"
        );
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
            "Token allowance is insufficient"
        )


        IERC20 token = IERC20(token);
        token.transferFrom(msg.sender, address(this), _amount);

        if (msg.sender == partyA) {
            partyAPaid = true;
        } else {
            partyBPaid = true;
        }

        if (partyAPaid && partyBPaid) {
            deadline = block.timestamp + 1 days;
            active = true;
        }
    }

    function declareWinner(address _winner) external onlyArbiter {
        require(active, "Escrow is not active");
        require()
    }

}
