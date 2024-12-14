// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UserStorage is Ownable {
    uint256 public bets;
    uint256 public victories;
    uint256 public losses;
    address[] public activeBets;
    mapping(address => Wager) public wagers;

    struct Wager {
        address betContract;
        address proposer;
        address acceptor;
        address arbiter;
        address fundToken;
        uint256 amount;
        uint256 deadline;
        bool accepted;
        string message;
    }

    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    function createBet(
        address _betContract,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _message
    ) external {
        Wager memory wager = Wager({
            betContract: _betContract,
            proposer: owner(),
            acceptor: address(0),
            arbiter: _arbiter,
            fundToken: _fundToken,
            amount: _amount,
            accepted: false,
            deadline: _deadline,
            message: _message
        });

        // Store the proposal
        wagers[_betContract] = wager;
        activeBets.push(_betContract);
    }

    function acceptBet(Wager memory _wager) external {
        Wager memory liveBet = Wager({
            betContract: _wager.betContract,
            proposer: _wager.proposer,
            acceptor: owner(),
            arbiter: _wager.arbiter,
            fundToken: _wager.fundToken,
            amount: _wager.amount,
            accepted: true,
            deadline: _wager.deadline,
            message: _wager.message
        });
        // store the livebet
        wagers[_wager.betContract] = liveBet;
    }

    /**
     * @dev Get all the bets
     * @return Wager[] array of bets
     */
    function getBets() external view returns (Wager[] memory) {
        Wager[] memory _bets = new Wager[](activeBets.length);
        for (uint256 i = 0; i < activeBets.length; i++) {
            _bets[i] = wagers[activeBets[i]];
        }
        return _bets;
    }
}
