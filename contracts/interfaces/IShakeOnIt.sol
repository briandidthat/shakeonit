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
        address initiator;
        address acceptor;
        address arbiter;
        address winner;
        address fundToken;
        uint256 amount;
        uint256 deadline;
        bool accepted;
        string message;
    }

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

    event BetUpdated(
        BetDetails betDetails
    );

    event BetWon(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        address fundToken,
        uint256 amount
    );

    event BetSettled(
        address indexed betAddress,
        address indexed winner,
        address indexed arbiter,
        address fundToken,
        uint256 amount
    );

    event BetCancelled(address indexed betAddress, address indexed initiator);
    event ArbiterBlocked(address indexed arbiter, string reason);
}
