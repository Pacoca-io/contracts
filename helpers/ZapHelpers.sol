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

import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IZapStructs.sol";
import "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract ZapHelpers is IZapStructs {
    function _getPairInfo(
        address _pair
    ) internal view returns (
        Pair memory tokens
    ) {
        IPancakePair pair = IPancakePair(_pair);

        uint balance = IPancakePair(_pair).balanceOf(msg.sender);

        return Pair(pair.token0(), pair.token1());
    }

    function _getBalance(address _token) internal view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }

    // TODO: Add pure back again
    function _calculateUnZapProfit(
        uint _initialBalance,
        uint _currentBalance,
        uint _minOutput
    ) internal returns (uint) {
        uint profit = _currentBalance - _initialBalance;

        console.log('Curr: %s | Initial: %s', _currentBalance, _initialBalance);

        require(
            profit > 0 && profit >= _minOutput,
            "PeanutZap:: Insufficient output token amount"
        );

        return profit;
    }
}
