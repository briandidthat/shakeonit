// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Restricted.sol";

contract UserStorage is IShakeOnIt, Restricted {
    uint256 private victories;
    uint256 private losses;
    uint256 private pnl;
    address[] private bets;
    mapping(address => BetDetails) public betDetailsRegistry;
    mapping(address => uint256) public balances;

    constructor(address _owner, Requestor[] memory contracts) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        // grant the owner role to the owner
        _grantRole(OWNER_ROLE, _owner);
        // grant the contract role to the contracts
        for (uint256 i = 0; i < contracts.length; i++) {
            Requestor memory requestor = contracts[i];
            _grantRole(requestor.role, requestor.caller);
        }
    }

    /**
     * @dev Deposit tokens
     * @param _token address of the token
     * @param _amount amount of the token
     */
    function deposit(
        address _token,
        uint256 _amount
    ) external onlyRole(OWNER_ROLE) {
        IERC20 token = IERC20(_token);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        balances[_token] += _amount;
    }

    /**
     * @dev Withdraw tokens
     * @param _token address of the token
     * @param _amount amount of the token
     */
    function withdraw(
        address _token,
        uint256 _amount
    ) external onlyRole(OWNER_ROLE) {
        require(balances[_token] >= _amount, "Insufficient balance");
        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        balances[_token] -= _amount;
    }

    /**
     * @dev store a bet contract
     * @param _betDetails BetDetails struct
     */
    function saveBet(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        BetDetails storage bet = betDetailsRegistry[_betDetails.betContract];
        // if bet is not already stored, add it to the list
        if (bet.betContract == address(0)) {
            bets.push(_betDetails.betContract);
        }
        // grant the write access role to the bet contract
        _grantRole(WRITE_ACCESS_ROLE, _betDetails.betContract);

        // store the bet details
        betDetailsRegistry[_betDetails.betContract] = _betDetails;
    }

    /**
     * @dev Record a victory
     * @param _betDetails BetDetails struct
     */
    function recordVictory(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        // increment the victories
        victories++;
        // update the pnl
        pnl += _betDetails.payout;
        // store the updated bet details
        betDetailsRegistry[_betDetails.betContract] = _betDetails;
    }

    /**
     * @dev Record a loss
     * @param _betDetails BetDetails struct
     */
    function recordLoss(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        // get the bet details from storage and increment the losses
        losses++;
        // update the pnl
        pnl -= _betDetails.amount;
        // store the updated bet details
        betDetailsRegistry[_betDetails.betContract] = _betDetails;
    }

    /**
     * @dev Cancel a bet
     * @param _betContract address of the bet contract
     */
    function cancelBet(
        address _betContract
    ) external onlyRole(WRITE_ACCESS_ROLE) {
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
     * @dev Grant approval to a spender
     * @param _token address of the token
     * @param _spender address of the spender
     * @param _amount amount to approve
     */
    function grantApproval(
        address _token,
        address _spender,
        uint256 _amount
    ) external onlyRole(OWNER_ROLE) {
        require(_amount > 0, "Amount must be greater than 0");
        // approve the spender to spend the amount
        IERC20(_token).approve(_spender, _amount);
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
        return bets.length;
    }

    /**
     * @dev Get balance of the provided token
     * @return uint256 balance of the token
     */
    function getTokenBalance(address _token) external view returns (uint256) {
        return balances[_token];
    }
}
