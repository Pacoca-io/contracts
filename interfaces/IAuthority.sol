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

interface IAuthority {
    // TODO check if possible to upgrade and add new roles
    enum Role {
        DAO,
        OWNER,
        TREASURY,
        KEEPER,
        MANAGER,
        REWARD_DISTRIBUTOR
    }

    event SetRole(Role indexed role, address indexed user, bool active);

    function dao() external view returns (address);

    function treasury() external view returns (address);

    function rewardDistributor() external view returns (address);

    function userRoles(Role, address) external view returns (bool);
}
