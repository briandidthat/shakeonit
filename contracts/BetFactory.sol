// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.0;

import "./Bet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BetFactory is Ownable {
    address publice implementation
    address[] public deployedBets;
    mapping(address => address[]) public userBets;

    constructor() {
        implementation = address(new Bet());
    }
}