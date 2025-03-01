// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

interface IShakeOnIt {
    struct User {
        bytes32 username;
        address signer;
        address userContract;
    }

    enum BetStatus {
        CREATED,
        INITIATED,
        FUNDED,
        WON,
        SETTLED,
        CANCELLED
    }

    enum BetType {
        OPEN_BET,
        PRIVATE_BET
    }

    struct BetDetails {
        BetType betType;
        BetStatus status;
        address betContract;
        address token;
        address creator;
        address arbiter;
        address challenger;
        address winner;
        address loser;
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
    }

    struct BetRequest {
        BetType betType;
        address token;
        User creator;
        User arbiter;
        User challenger;
        uint256 stake;
        uint256 arbiterFee;
        uint256 platformFee;
        uint256 payout;
        string condition;
    }
}
