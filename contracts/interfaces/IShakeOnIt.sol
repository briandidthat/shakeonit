// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

interface IShakeOnIt {
    enum BetStatus {
        INITIATED,
        FUNDED,
        WON,
        SETTLED,
        CANCELLED
    }

    struct BetDetails {
        address betContract;
        address token;
        address initiator;
        address arbiter;
        address acceptor;
        address winner;
        address loser;
        uint256 amount;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
        uint256 deadline;
        BetStatus status;
    }

    event BetCreated(
        address indexed betAddress,
        address indexed initiator,
        address indexed arbiter,
        address token,
        uint256 amount,
        uint256 deadline
    );

    event BetAccepted(
        address indexed betAddress,
        address indexed acceptor,
        address indexed token,
        uint256 amount,
        uint256 deadline
    );

    event BetWon(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        address token,
        uint256 amount
    );

    event BetSettled(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        address token,
        uint256 amount
    );

    event BetCancelled(address indexed betAddress, address indexed initiator);
}
