// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./interfaces/IShakeOnIt.sol";
import "./Restricted.sol";
import "./Bet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UserStorage is IShakeOnIt, Restricted {
    address private owner;
    uint256 private victories;
    uint256 private losses;
    mapping(address => uint256) public balances;

    constructor(address _owner) {
        // grant the owner role to the owner
        _grantRole(OWNER_ROLE, _owner);
        // grant the write access role to the deployer
        _grantRole(WRITE_ACCESS_ROLE, msg.sender);
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
     * @dev Get balance of the provided token
     * @return uint256 balance of the token
     */
    function getTokenBalance(address _token) external view returns (uint256) {
        return balances[_token];
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}
