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

import "./SweetVault_v4_CAKE.sol";
import "./interfaces/ICakePool.sol";

contract SweetVault_v4_CAKE_v2 is SweetVault_v4_CAKE {
    uint public profitSlippage;

    function harvest() internal override {
        uint currentProfit = profit();

        ICakePool(CAKE_POOL).withdrawByAmount(currentProfit - currentProfit / profitSlippage);

        (uint currentShares, , , , , , , ,) = ICakePool(CAKE_POOL).userInfo(address(this));

        require(
            _sharesToCake(currentShares) >= _totalStake,
            "harvest:: Insufficient balance"
        );
    }

    function setProfitSlippage(uint _profitSlippage) external requireRole(ROLE_OWNER) {
        profitSlippage = _profitSlippage;
    }
}
