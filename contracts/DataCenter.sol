// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./Arbiter.sol";
import "./BetManagement.sol";
import "./UserManagement.sol";
import "./ArbiterManagement.sol";

contract DataCenter is Ownable {
    address private multiSigWallet;
    UserManagement private userManagement;
    ArbiterManagement private arbiterManagement;
    BetManagement private betManagement;

    event MultiSigChanged(
        address indexed oldMultiSig,
        address indexed newMultiSig
    );

    constructor(
        address _factory,
        address _multiSigWallet
    ) Ownable(_multiSigWallet) {
        multiSigWallet = _multiSigWallet;
        userManagement = new UserManagement(multiSigWallet);
        arbiterManagement = new ArbiterManagement(_multiSigWallet);
        betManagement = new BetManagement(_multiSigWallet, _factory);
    }

    function setNewMultiSig(address _newMultiSig) external onlyOwner {
        require(_newMultiSig != address(0), "Zero address not allowed");
        require(_newMultiSig != owner(), "Owner cannot be the new multi-sig");
        // transfer ownership to the new multi-sig
        _transferOwnership(_newMultiSig);
        // emit MultiSigChanged event
        emit MultiSigChanged(_newMultiSig, multiSigWallet);
    }

    function getMultiSig() external view returns (address) {
        return multiSigWallet;
    }

    function getBetManagement() external view returns (address) {
        return address(betManagement);
    }

    function getUserManagement() external view returns (address) {
        return address(userManagement);
    }

    function getUserStorage(address _user) external view returns (address) {
        return userManagement.getUserStorage(_user);
    }

    function getArbiterManagement() external view returns (address) {
        return address(arbiterManagement);
    }

    function isArbiter(address _arbiter) external view returns (bool) {
        return arbiterManagement.isArbiter(_arbiter);
    }

    function isUser(address _user) external view returns (bool) {
        return userManagement.isUser(_user);
    }
}
