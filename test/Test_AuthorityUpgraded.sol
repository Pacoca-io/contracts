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

import "../access/Authority.sol";
import "./Test_ControlledUUPSUpgraded.sol";

contract Test_AuthorityUpgraded is Test_ControlledUUPSUpgraded, Authority {
    function setAuthority(address) external pure override(AccessControlled, Authority) {
        revert("Authority::setAuthority: Can't change authority of Authority contract");
    }
}
