// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vbux is ERC20, Ownable {
    constructor() ERC20("Virtual Bucks", "VBUX") Ownable(msg.sender) {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }
}
