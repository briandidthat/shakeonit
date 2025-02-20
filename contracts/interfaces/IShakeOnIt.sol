// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

interface IShakeOnIt {
    enum BetStatus {
        CREATED,
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
        UserDetails initiator;
        UserDetails arbiter;
        UserDetails acceptor;
        address winner;
        address loser;
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
        BetStatus status;
    }

    struct BetRequest {
        address token;
        UserDetails initiator;
        UserDetails arbiter;
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
        string condition;
    }
}
