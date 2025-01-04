// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./UserStorage.sol";
import "./BetManagement.sol";
import "./UserManagement.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DataCenter is Ownable {
    address private multiSigWallet;
    address private userManagement;
    address private betManagement;

    event MultiSigChanged(
        address indexed oldMultiSig,
        address indexed newMultiSig
    );
    event UserManagementChanged(
        address indexed oldUserManagement,
        address indexed newUserManagement
    );
    event BetManagementChanged(
        address indexed oldBetManagement,
        address indexed newBetManagement
    );

    constructor(
        address _multiSigWallet,
        address _userManagement,
        address _betManagement
    ) Ownable(_multiSigWallet) {
        multiSigWallet = _multiSigWallet;
        userManagement = _userManagement;
        betManagement = _betManagement;
    }

    function setNewMultiSig(address _newMultiSig) external onlyOwner {
        require(_newMultiSig != address(0), "Zero address not allowed");
        require(_newMultiSig != owner(), "Owner cannot be the new multi-sig");

        // transfer ownership to the new multi-sig
        _transferOwnership(_newMultiSig);
        // emit MultiSigChanged event
        emit MultiSigChanged(multiSigWallet, _newMultiSig);
        // update the multiSigWallet address
        multiSigWallet = _newMultiSig;
    }

    function setNewUserManagement(
        address _newUserManagement
    ) external onlyOwner {
        require(_newUserManagement != address(0), "Zero address not allowed");
        require(
            _newUserManagement != address(userManagement),
            "UserManagement address is the same"
        );
        // emit UserManagementChanged event
        emit UserManagementChanged(userManagement, _newUserManagement);
        // update the userManagement address
        userManagement = _newUserManagement;
    }

    function setNewBetManagement(address _newBetManagement) external onlyOwner {
        require(_newBetManagement != address(0), "Zero address not allowed");
        require(
            _newBetManagement != betManagement,
            "BetManagement address is the same"
        );
        // emit BetManagementChanged event
        emit BetManagementChanged(_newBetManagement, betManagement);
        // update the betManagement address
        betManagement = _newBetManagement;
    }

    function isUser(address _user) external view returns (bool) {
        return UserManagement(userManagement).isUser(_user);
    }

    function getMultiSig() external view returns (address) {
        return multiSigWallet;
    }

    function getUserManagement() external view returns (address) {
        return userManagement;
    }

    function getBetManagement() external view returns (address) {
        return betManagement;
    }
}
