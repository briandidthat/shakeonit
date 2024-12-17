// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UserStorage is IShakeOnIt, Ownable {
    address private dataCenter;
    uint256 private bets;
    uint256 private victories;
    uint256 private losses;
    address[] private activeBets;
    mapping(address => Wager) public wagers;

    modifier onlyDataCenter() {
        require(msg.sender == dataCenter, "Restricted to DataCenter");
        _;
    }

    constructor(address _owner, address _dataCenter) Ownable(_owner) {
        dataCenter = _dataCenter;
    }

    /**
     * @dev Create a bet
     * @param _betContract address of the bet contract
     * @param _arbiter address of the arbiter
     * @param _fundToken address of the token to be used for the bet
     * @param _amount amount of the bet
     * @param _deadline deadline for the bet
     * @param _message message for the bet
     */
    function createBet(
        address _betContract,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _message
    ) external onlyDataCenter {
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

    /**
     * @dev Accept a bet
     * @param _wager Wager struct
     */
    function acceptBet(Wager memory _wager) external onlyDataCenter {
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

    function getBetCount() external view returns (uint256) {
        return activeBets.length;
    }
}
