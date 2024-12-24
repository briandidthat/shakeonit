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
    address private betFactory;
    UserManagement private userManagement;
    ArbiterManagement private arbiterManagement;
    BetManagement private betManagement;

    event MultiSigChanged(
        address indexed oldMultiSig,
        address indexed newMultiSig
    );

    constructor(
        address _multiSigWallet,
        address _factory
    ) Ownable(_multiSigWallet) {
        multiSigWallet = _multiSigWallet;
        betFactory = _factory;
        // create the user management contract
        userManagement = new UserManagement(multiSigWallet);
        // create the arbiter management contract
        arbiterManagement = new ArbiterManagement(_multiSigWallet);
        // create the bet management contract
        betManagement = new BetManagement(_multiSigWallet, address(this));
    }

    function setNewMultiSig(address _newMultiSig) external onlyOwner {
        require(_newMultiSig != address(0), "Zero address not allowed");
        require(_newMultiSig != owner(), "Owner cannot be the new multi-sig");
        // transfer ownership to the new multi-sig
        _transferOwnership(_newMultiSig);
        // update the multi-sig address
        multiSigWallet = _newMultiSig;
        // emit MultiSigChanged event
        emit MultiSigChanged(_newMultiSig, multiSigWallet);
    }

    function getMultiSig() external view returns (address) {
        return multiSigWallet;
    }

    function getUserManagement() external view returns (UserManagement) {
        return userManagement;
    }

    function getArbiterManagement() external view returns (ArbiterManagement) {
        return arbiterManagement;
    }

    function getBetManagement() external view returns (BetManagement) {
        return betManagement;
    }

    function getBetFactory() external view returns (address) {
        return betFactory;
    }

    function getUserStorage(address _user) external view returns (address) {
        return userManagement.getUserStorage(_user);
    }

    function getArbiter(address _arbiter) external view returns (address) {
        return arbiterManagement.getArbiter(_arbiter);
    }

    function isArbiter(address _arbiter) external view returns (bool) {
        return arbiterManagement.isArbiter(_arbiter);
    }

    function isUser(address _user) external view returns (bool) {
        return userManagement.isUser(_user);
    }
}
