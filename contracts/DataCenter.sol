// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./UserStorage.sol";
import "./Arbiter.sol";
import "./BetManagement.sol";
import "./UserManagement.sol";
import "./ArbiterManagement.sol";
import "./BetFactory.sol";

contract DataCenter is Ownable {
    address private multiSigWallet;
    BetFactory private betFactory;
    UserManagement private userManagement;
    ArbiterManagement private arbiterManagement;
    BetManagement private betManagement;

    event MultiSigChanged(
        address indexed oldMultiSig,
        address indexed newMultiSig
    );

    constructor(address _multiSigWallet) Ownable(_multiSigWallet) {
        multiSigWallet = _multiSigWallet;
        // create pointer to the bet factory contract
        betFactory = new BetFactory(multiSigWallet, address(this));
        // deploy new user management contract
        userManagement = new UserManagement(multiSigWallet, address(this));
        // create pointer to the arbiter management contract
        arbiterManagement = new ArbiterManagement(
            _multiSigWallet,
            address(this)
        );
        // create pointer to the bet management contract
        betManagement = new BetManagement(multiSigWallet, address(this));
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

    function getUserManagement() external view returns (address) {
        return address(userManagement);
    }

    function getArbiterManagement() external view returns (address) {
        return address(arbiterManagement);
    }

    function getBetManagement() external view returns (address) {
        return address(betManagement);
    }

    function getBetFactory() external view returns (address) {
        return address(betFactory);
    }

    function getUserStorage(address _user) external view returns (address) {
        return userManagement.getUserStorage(_user);
    }

    function getArbiter(address _arbiter) external view returns (address) {
        return arbiterManagement.getArbiter(_arbiter);
    }

    function isArbiter(address _arbiter) external view returns (bool) {
        return arbiterManagement.isRegistered(_arbiter);
    }

    function isUser(address _user) external view returns (bool) {
        return userManagement.isUser(_user);
    }

    /**
     * @dev Register a new user
     * @param _user The address of the user
     */
    function registerUser(address _user) external {
        userManagement.addUser(_user);
    }

    /**
     * @dev Register a new arbiter
     * @param _arbiter The address of the arbiter
     */
    function registerArbiter(address _arbiter) external onlyOwner {
        arbiterManagement.addArbiter(_arbiter);
    }
}
