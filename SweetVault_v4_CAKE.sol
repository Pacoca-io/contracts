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

import "./SweetVault_v4.sol";
import "./interfaces/ICakePool.sol";

contract SweetVault_v4_CAKE is SweetVault_v4 {
    address constant public CAKE_POOL = 0x45c54210128a065de780C4B0Df3d16664f7f859e;
    address constant public CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    uint internal _totalStake;

    function harvest() internal override {
        ICakePool(CAKE_POOL).withdrawByAmount(profit());
    }

    function profit() public view returns (uint) {
        ICakePool cakePool = ICakePool(CAKE_POOL);

        (uint shares, , , , , , , ,) = cakePool.userInfo(address(this));

        return shares * cakePool.getPricePerFullShare() / 1e18 - _totalStake;
    }

    function totalStake() public view override returns (uint) {
        return _totalStake;
    }
}
