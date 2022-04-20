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

import "./Test_AuthorityTest.sol";
import "./Test_ControlledUUPSUpgraded.sol";

contract Test_AuthorityTestUpgraded is Test_AuthorityTest, Test_ControlledUUPSUpgraded {
    function onlyTestRole() public requireRole(ROLE_TEST) {
        emit Called('onlyTestRole');
    }
}
