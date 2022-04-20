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

import "../access/ControlledUUPS.sol";

contract Test_AuthorityTest is ControlledUUPS {
    event Called(string);

    function initialize(address _authority) public initializer {
        __ControlledUUPS_init(_authority);
    }

    function onlyOwner() public requireRole(ROLE_OWNER) {
        emit Called('onlyOwner');
    }

    function onlyDao() public requireRole(ROLE_DAO) {
        emit Called('onlyDao');
    }

    function onlyTreasury() public requireRole(ROLE_TREASURY) {
        emit Called('onlyTreasury');
    }

    function onlyManager() public requireRole(ROLE_MANAGER) {
        emit Called('onlyManager');
    }

    function onlyKeeper() public requireRole(ROLE_KEEPER) {
        emit Called('onlyKeeper');
    }

    function onlyRewardDistributor() public requireRole(ROLE_REWARD_DISTRIBUTOR) {
        emit Called('onlyRewardDistributor');
    }
}
