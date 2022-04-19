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

import "../interfaces/IAuthority.sol";
import "./ControlledUUPS.sol";

contract Authority is IAuthority, ControlledUUPS {
    address public treasury;
    address public dao;
    address public rewardDistributor;

    mapping(Role => mapping(address => bool)) public userRoles;

    function initialize(
        address _dao,
        address _owner,
        address _treasury,
        address _keeper,
        address _manager,
        address _rewardDistributor
    ) public initializer {
        _setRole(Role.DAO, _dao, true);
        _setRole(Role.OWNER, _owner, true);
        _setRole(Role.TREASURY, _treasury, true);
        _setRole(Role.KEEPER, _keeper, true);
        _setRole(Role.MANAGER, _manager, true);
        _setRole(Role.REWARD_DISTRIBUTOR, _rewardDistributor, true);

        __ControlledUUPS_init(address(this));
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
        if (_role == Role.DAO && _active) {
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

        if (_role == Role.REWARD_DISTRIBUTOR && _active) {
            require(
                _user != address(0),
                "Authority::_setRole: Reward distributor cannot be zero address"
            );

            userRoles[_role][rewardDistributor] = false;
            rewardDistributor = _user;
        }

        userRoles[_role][_user] = _active;

        emit SetRole(_role, _user, _active);
    }
}
