/**
                                                         __
     _____      __      ___    ___     ___     __       /\_\    ___
    /\ '__`\  /'__`\   /'___\ / __`\  /'___\ /'__`\     \/\ \  / __`\
    \ \ \_\ \/\ \_\.\_/\ \__//\ \_\ \/\ \__//\ \_\.\_  __\ \ \/\ \_\ \
     \ \ ,__/\ \__/.\_\ \____\ \____/\ \____\ \__/.\_\/\_\\ \_\ \____/
      \ \ \/  \/__/\/_/\/____/\/___/  \/____/\/__/\/_/\/_/ \/_/\/___/
       \ \_\
        \/_/

    The sweetest DeFi portfolio manager.

**/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable-v4/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IAuthority.sol";
import "./AccessControlled.sol";

contract Authority is IAuthority, AccessControlled, UUPSUpgradeable {
    mapping(Role => mapping(address => bool)) public userRoles;

    function initialize(
        address _dao,
        address _keeper,
        address _manager
    ) public initializer {
        _setRole(Role.DAO, _dao, true);
        _setRole(Role.KEEPER, _keeper, true);
        _setRole(Role.MANAGER, _manager, true);
    }

    function setRole(
        Role _role,
        address _user,
        bool _active
    ) external requireRole(Role.DAO) {
        _setRole(_role, _user, _active);
    }

    function _setRole(
        Role _role,
        address _user,
        bool _active
    ) internal {
        userRoles[_role][_user] = _active;

        emit SetRole(_role, _user, _active);
    }

    function _authorizeUpgrade(address) internal override requireRole(Role.DAO) {}
}
