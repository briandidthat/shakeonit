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
    mapping(address => BetDetails) public betDetails;
    mapping(address => address) public betContracts;

    modifier onlyDataCenter() {
        require(msg.sender == dataCenter, "Restricted to DataCenter");
        _;
    }

    constructor(address _owner, address _dataCenter) Ownable(_owner) {
        dataCenter = _dataCenter;
    }

    /**
     * @dev Save a new bet
     * @param _betContract address of the bet contract
     * @param _arbiter address of the arbiter
     * @param _fundToken address of the token to be used for the bet
     * @param _amount amount of the bet
     * @param _deadline deadline for the bet
     * @param _message message for the bet
     */
    function saveBet(
        address _betContract,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _message
    ) external onlyDataCenter {
        BetDetails memory BetDetails = BetDetails({
            betContract: _betContract,
            initiator: owner(),
            acceptor: address(0),
            arbiter: _arbiter,
            fundToken: _fundToken,
            amount: _amount,
            accepted: false,
            deadline: _deadline,
            message: _message
        });

        // Store the proposal
        betDetails[_betContract] = BetDetails;
        activeBets.push(_betContract);
    }

    /**
     * @dev Update the bet status
     * @param _betDetails BetDetails struct
     */
    function finalizeBet(BetDetails memory _betDetails) external {
        // this function should be called by the bet contract itself
        BetDetails storage bet = betDetails[msg.sender];
        require(bet.betContract == msg.sender, "Invalid bet contract");

        // update the bet status
        betDetails[_betDetails.betContract] = _betDetails;
    }

    /**
     * @dev Accept a bet
     * @param _betDetails BetDetails struct
     */
    function acceptBet(BetDetails memory _betDetails) external onlyDataCenter {
        // update the bet status
        BetDetails memory liveBet = BetDetails({
            betContract: _betDetails.betContract,
            initiator: _betDetails.initiator,
            acceptor: owner(),
            arbiter: _betDetails.arbiter,
            fundToken: _betDetails.fundToken,
            amount: _betDetails.amount,
            accepted: true,
            deadline: _betDetails.deadline,
            message: _betDetails.message
        });
        // store the livebet
        betDetails[_betDetails.betContract] = liveBet;
    }

    /**
     * @dev Cancel a bet
     * @param _betContract address of the bet contract
     */
    function cancelBet(address _betContract) external onlyDataCenter {
        // remove the bet from the active bets
        for (uint256 i = 0; i < activeBets.length; i++) {
            if (activeBets[i] == _betContract) {
                activeBets[i] = activeBets[activeBets.length - 1];
                activeBets.pop();
                break;
            }
        }
        // delete the bet
        delete betDetails[_betContract];
    }

    /**
     * @dev Get a bet
     * @param _betContract address of the bet contract
     * @return BetDetails struct
     */
    function getBetDetails(
        address _betContract
    ) external view returns (BetDetails memory) {
        return betDetails[_betContract];
    }

    /**
     * @dev Get all the bets
     * @return BetDetails[] array of bets
     */
    function getBets() external view returns (BetDetails[] memory) {
        BetDetails[] memory _bets = new BetDetails[](activeBets.length);
        for (uint256 i = 0; i < activeBets.length; i++) {
            _bets[i] = betDetails[activeBets[i]];
        }
        return _bets;
    }

    function getBetCount() external view returns (uint256) {
        return activeBets.length;
    }
}
