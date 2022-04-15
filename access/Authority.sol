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
    address public treasury;
    address public dao;

    mapping(Role => mapping(address => bool)) public userRoles;

    function initialize(
        address _dao,
        address _treasury,
        address _keeper,
        address _manager
    ) public initializer {
        _setRole(Role.OWNER, _dao, true);
        _setRole(Role.TREASURY, _treasury, true);
        _setRole(Role.KEEPER, _keeper, true);
        _setRole(Role.MANAGER, _manager, true);

        __AccessControlled_init(IAuthority(address(this)));
    }

    function setRole(
        Role _role,
        address _user,
        bool _active
    ) external requireRole(Role.OWNER) {
        _setRole(_role, _user, _active);
    }

    function _setRole(
        Role _role,
        address _user,
        bool _active
    ) internal {
        if (_role == Role.OWNER && _active) {
            require(
                _user != address(0),
                "Authority::_setRole: Owner cannot be zero address"
            );

            userRoles[_role][dao] = false;
            dao = _user;
        }

        if (_role == Role.TREASURY && _active) {
            require(
                _user != address(0),
                "Authority::_setRole: Treasury cannot be zero address"
            );

            userRoles[_role][treasury] = false;
            treasury = _user;
        }

        userRoles[_role][_user] = _active;

        emit SetRole(_role, _user, _active);
    }

    function _authorizeUpgrade(address) internal override requireRole(Role.OWNER) {}
}
