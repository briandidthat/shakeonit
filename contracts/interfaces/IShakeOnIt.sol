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

    struct UserDetails {
        address owner;
        address storageAddress;
    }

    struct BetDetails {
        address betContract;
        address token;
        address initiator;
        address arbiter;
        address acceptor;
        address winner;
        address loser;
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
        BetStatus status;
    }
}
