// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "./Restricted.sol";
import "./interfaces/IShakeOnIt.sol";

contract BetStorage is IShakeOnIt, Restricted {
    address[] public deployedBets;
    mapping(address => bool) private isBet;
    mapping(address => address[]) userBetAddresses;
    mapping(address => mapping(address => BetDetails)) public userBetDetails;

    constructor(address _multiSig, address _betManagement) {
        // grant the default admin role to the multiSig address
        _grantRole(DEFAULT_ADMIN_ROLE, _multiSig);
        // set the owner role to the multiSig address
        _grantRole(MULTISIG_ROLE, _multiSig);
        // grant the WRITE_ACCESS_ROLE to the BetManagement contract
        _grantRole(WRITE_ACCESS_ROLE, _betManagement);
    }

    function createBet(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        // update the state
        deployedBets.push(_betDetails.betContract);
        userBetAddresses[_betDetails.initiator].push(_betDetails.betContract);
        userBetAddresses[_betDetails.arbiter].push(_betDetails.betContract);
    }

    function acceptBet(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        require(isBet[_betDetails.betContract], "Bet does not exist");
        // add the bet contract to the userBetAddresses mapping
        userBetAddresses[_betDetails.acceptor].push(_betDetails.betContract);
        // add the bet details to the userBetDetails mapping
        userBetDetails[_betDetails.acceptor][
            _betDetails.betContract
        ] = _betDetails;
        userBetDetails[_betDetails.initiator][
            _betDetails.betContract
        ] = _betDetails;
        userBetDetails[_betDetails.arbiter][
            _betDetails.betContract
        ] = _betDetails;
    }

    function getUserBets(
        address _user
    ) external view returns (address[] memory) {
        return userBetAddresses[_user];
    }

    function declareWinner(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        require(isBet[_betDetails.betContract], "Bet does not exist");
        userBetDetails[_betDetails.winner][
            _betDetails.betContract
        ] = _betDetails;
        userBetDetails[_betDetails.loser][
            _betDetails.betContract
        ] = _betDetails;
        userBetDetails[_betDetails.arbiter][
            _betDetails.betContract
        ] = _betDetails;
    }

    function cancelBet(
        BetDetails memory _betDetails
    ) external onlyRole(WRITE_ACCESS_ROLE) {
        require(isBet[_betDetails.betContract], "Bet does not exist");
        _betDetails.status = BetStatus.CANCELLED;
        userBetDetails[_betDetails.initiator][
            _betDetails.betContract
        ] = _betDetails;
        userBetDetails[_betDetails.arbiter][
            _betDetails.betContract
        ] = _betDetails;
    }
}
