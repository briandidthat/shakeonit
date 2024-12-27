// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./UserStorage.sol";
import "./Arbiter.sol";
import "./BetManagement.sol";
import "./UserManagement.sol";
import "./ArbiterManagement.sol";
import "./BetFactory.sol";
import "./Restricted.sol";

contract DataCenter is Restricted {
    address private multiSigWallet;
    BetFactory private betFactory;
    UserManagement private userManagement;
    ArbiterManagement private arbiterManagement;
    BetManagement private betManagement;
    Requestor[] private contracts;

    event MultiSigChanged(
        address indexed oldMultiSig,
        address indexed newMultiSig
    );

    constructor(address _multiSigWallet) {
        multiSigWallet = _multiSigWallet;
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSigWallet);
        _grantRole(MULTISIG_ROLE, _multiSigWallet);
    }

    function initialize(
        address _userManagement,
        address _arbiterManagement,
        address _betManagement,
        address _betFactory,
        Requestor[] memory _contracts
    ) external onlyRole(MULTISIG_ROLE) {
        betFactory = BetFactory(_betFactory);
        userManagement = UserManagement(_userManagement);
        arbiterManagement = ArbiterManagement(_arbiterManagement);
        betManagement = BetManagement(_betManagement);
        // add the provided contracts to the contracts array
        for (uint256 i = 0; i < _contracts.length; i++) {
            contracts.push(_contracts[i]);
        }
        // initialize the contracts
        userManagement.initialize(contracts);
        arbiterManagement.initialize(contracts);
        betManagement.initialize(contracts);
    }

    function setNewMultiSig(
        address _newMultiSig
    ) external onlyRole(MULTISIG_ROLE) {
        require(_newMultiSig != address(0), "Zero address not allowed");
        require(
            _newMultiSig != multiSigWallet,
            "Owner cannot be the new multi-sig"
        );
        // transfer ownership to the new multi-sig
        _grantRole(MULTISIG_ROLE, _newMultiSig);
        _grantRole(DEFAULT_ADMIN_ROLE, _newMultiSig);
        // remove the ownership from the old multi-sig
        _removeRole(MULTISIG_ROLE, multiSigWallet);
        _removeRole(DEFAULT_ADMIN_ROLE, multiSigWallet);
        // update the multi-sig address
        multiSigWallet = _newMultiSig;
        // emit MultiSigChanged event
        emit MultiSigChanged(_newMultiSig, multiSigWallet);
    }

    /**
     * @dev Register a new user
     * @param _user The address of the user
     */
    function registerUser(address _user) external onlyRole(WRITE_ACCESS_ROLE) {
        userManagement.addUser(_user, contracts);
    }

    /**
     * @dev Register a new arbiter
     * @param _arbiter The address of the arbiter
     */
    function registerArbiter(
        address _arbiter
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        arbiterManagement.addArbiter(_arbiter, contracts);
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

    function getArbiter(address _arbiter) external view returns (address) {
        return arbiterManagement.getArbiter(_arbiter);
    }

    function isArbiter(address _arbiter) external view returns (bool) {
        return arbiterManagement.isRegistered(_arbiter);
    }

    function isUser(address _user) external view returns (bool) {
        return userManagement.isUser(_user);
    }

    function getUserStorage(address _user) external view returns (address) {
        return userManagement.getUserStorage(_user);
    }
}
