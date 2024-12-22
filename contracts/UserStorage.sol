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
    mapping(address => uint256) public balances;

    modifier onlyDataCenter() {
        require(msg.sender == dataCenter, "Restricted to DataCenter");
        _;
    }

    constructor(address _owner, address _dataCenter) Ownable(_owner) {
        dataCenter = _dataCenter;
    }

    /**
     * @dev Deposit tokens
     * @param _token address of the token
     * @param _amount amount of the token
     */
    function deposit(address _token, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_token);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        balances[_token] = _amount;
    }

    /**
     * @dev Withdraw tokens
     * @param _token address of the token
     * @param _amount amount of the token
     */
    function withdraw(address _token, uint256 _amount) external onlyOwner {
        require(balances[_token] >= _amount, "Insufficient balance");
        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        balances[_token] -= _amount;
    }

    /**
     * @dev store a bet contract
     * @param _betDetails BetDetails struct
     */
    function saveBet(BetDetails memory _betDetails) external onlyDataCenter {
        // set bet status to initiated
        _betDetails.status = BetStatus.INITIATED;

        // Store the proposal
        betDetailsRegistry[_betDetails.betContract] = _betDetails;
        bets.push(_betDetails.betContract);
        betCount++;
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
        // decrement the bet count
        betCount--;
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

    /**
     * @dev Get the number of bets
     * @return uint256 number of bets
     */
    function getBetCount() external view returns (uint256) {
        return betCount;
    }

    /**
     * @dev Get balance of the provided token
     * @return uint256 balance of the token
     */
    function getTokenBalance(address _token) external view returns (uint256) {
        return balances[_token];
    }
}
