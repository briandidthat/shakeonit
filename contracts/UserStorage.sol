// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UserStorage is IShakeOnIt, Ownable {
    address private dataCenter;
    uint256 private betCount;
    uint256 private victories;
    uint256 private losses;
    address[] private bets;
    mapping(address => BetDetails) public betDetailsRegistry;
    mapping(address => address) public betContracts;

    modifier onlyDataCenter() {
        require(msg.sender == dataCenter, "Restricted to DataCenter");
        _;
    }

    constructor(address _owner, address _dataCenter) Ownable(_owner) {
        dataCenter = _dataCenter;
    }

    /**
     * @dev Save a bet
     * @param _betContract address of the bet contract
     * @param _arbiter address of the arbiter
     * @param _fundToken address of the fund token
     * @param _amount amount of the bet
     * @param _deadline deadline of the bet
     * @param _message message of the bet
     * @return _betDetails BetDetails struct
     */
    function saveBet(
        address _betContract,
        address _arbiter,
        address _fundToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _message
    ) external onlyDataCenter returns (BetDetails memory _betDetails) {
        BetDetails memory betDetails = BetDetails({
            betContract: _betContract,
            initiator: owner(),
            acceptor: address(0),
            arbiter: _arbiter,
            winner: address(0),
            fundToken: _fundToken,
            amount: _amount,
            accepted: false,
            deadline: _deadline,
            message: _message
        });

        // Store the proposal
        betDetailsRegistry[_betContract] = betDetails;
        bets.push(_betContract);
        // return the bet details
        _betDetails = betDetails;
    }

    /**
     * @dev Update the bet status
     * @param _betDetails BetDetails struct
     */
    function updateBet(BetDetails memory _betDetails) external onlyDataCenter {
        // get the bet details from storage
        BetDetails storage bet = betDetailsRegistry[_betDetails.betContract];
        require(
            bet.betContract == _betDetails.betContract,
            "Invalid bet contract"
        );
        // store the updated bet details
        betDetailsRegistry[_betDetails.betContract] = _betDetails;
    }

    /**
     * @dev Cancel a bet
     * @param _betContract address of the bet contract
     */
    function cancelBet(address _betContract) external onlyDataCenter {
        // remove the bet from the active bets
        for (uint256 i = 0; i < bets.length; i++) {
            if (bets[i] == _betContract) {
                bets[i] = bets[bets.length - 1];
                bets.pop();
                break;
            }
        }
        // delete the bet
        delete betDetailsRegistry[_betContract];
    }

    /**
     * @dev Get a bet
     * @param _betContract address of the bet contract
     * @return BetDetails struct
     */
    function getBetDetails(
        address _betContract
    ) external view returns (BetDetails memory) {
        return betDetailsRegistry[_betContract];
    }

    /**
     * @dev Get all the bets
     * @return BetDetails[] array of bets
     */
    function getBets() external view returns (BetDetails[] memory) {
        BetDetails[] memory _bets = new BetDetails[](bets.length);
        for (uint256 i = 0; i < bets.length; i++) {
            _bets[i] = betDetailsRegistry[bets[i]];
        }
        return _bets;
    }

    function getBetCount() external view returns (uint256) {
        return betCount;
    }
}
