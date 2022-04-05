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
import "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract ZapHelpers {
    struct Pair {
        address token0;
        address token1;
    }

    struct ZapInfo {
        IPancakeRouter02 router;
        address[] pathToToken0;
        address[] pathToToken1;
        uint minToken0;
        uint minToken1;
    }

    struct UnZapInfo {
        IPancakeRouter02 router;
        address[] pathFromToken0;
        address[] pathFromToken1;
    }

    function _getPairInfo(
        address _pair
    ) internal view returns (
        Pair memory tokens
    ) {
        IPancakePair pair = IPancakePair(_pair);

        return Pair(pair.token0(), pair.token1());
    }

    function _approveUsingPermit(
        address _token,
        uint _inputTokenAmount,
        bytes calldata _signatureData
    ) internal {
        (uint8 v, bytes32 r, bytes32 s, uint deadline) = abi.decode(_signatureData, (uint8, bytes32, bytes32, uint));

        console.log('ZapHelpers: %s', address(this));
        console.log('ZapHelpers Sender: %s', msg.sender);

        IPancakePair(_token).permit(
            msg.sender,
            address(this),
            _inputTokenAmount,
            deadline,
            v,
            r,
            s
        );
    }

    function _getBalance(address _token) internal view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }

    function _calculateUnZapProfit(
        uint _initialBalance,
        uint _currentBalance,
        uint _minOutput
    ) internal pure returns (uint) {
        uint profit = _currentBalance - _initialBalance;

        require(
            profit > 0 && profit >= _minOutput,
            "PeanutZap:: Insufficient output token amount"
        );

        return profit;
    }

    function _decodeZapInfo(
        bytes calldata _zapInfo
    ) internal pure returns (
        ZapInfo memory
    ) {
        (
            IPancakeRouter02 router,
            address[] memory pathToToken0,
            address[] memory pathToToken1,
            uint minToken0,
            uint minToken1
        ) = abi.decode(
            _zapInfo,
            (IPancakeRouter02, address[], address[], uint, uint)
        );

        return ZapInfo(
            router,
            pathToToken0,
            pathToToken1,
            minToken0,
            minToken1
        );
    }

    function _decodeUnZapInfo(
        bytes calldata _zapInfo
    ) internal pure returns (
        UnZapInfo memory
    ) {
        (
            IPancakeRouter02 router,
            address[] memory pathFromToken0,
            address[] memory pathFromToken1
        ) = abi.decode(
            _zapInfo,
            (IPancakeRouter02, address[], address[])
        );

        return UnZapInfo(
            router,
            pathFromToken0,
            pathFromToken1
        );
    }
}
