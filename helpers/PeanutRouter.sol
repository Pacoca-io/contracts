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

import "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPancakeRouter02.sol";

contract PeanutRouter {
    using SafeERC20 for IERC20;

    function _swap(
        IPancakeRouter02 _router,
        uint _amountIn,
        uint _amountOutMin,
        address[] memory _path,
        address _to
    ) internal {
        _approveSpend(_path[0], address(_router), _amountIn);

        _router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            _amountOutMin,
            _path,
            _to,
            block.timestamp
        );
    }

    function _addLiquidity(
        IPancakeRouter02 _router,
        address _token0,
        address _token1,
        uint _input0,
        uint _input1,
        uint _minOut0,
        uint _minOut1,
        address _to
    ) internal {
        _approveSpend(_token0, address(_router), _input0);
        _approveSpend(_token1, address(_router), _input1);

        _router.addLiquidity(
            _token0,
            _token1,
            _input0,
            _input1,
            _minOut0,
            _minOut1,
            _to,
            block.timestamp
        );
    }

    function _removeLiquidity(
        IPancakeRouter02 _router,
        address _token0,
        address _token1,
        address _inputToken,
        uint _liquidity,
        uint _minOut0,
        uint _minOut1
    ) internal {
        _approveSpend(_inputToken, address(_router), _liquidity);

        // TODO support fee on transfer tokens
        _router.removeLiquidity(
            _token0,
            _token1,
            _liquidity,
            _minOut0, // TODO maybe care about output amounts
            _minOut1, // TODO maybe care about output amounts
            address(this),
            block.timestamp
        );
    }

    function _approveSpend(
        address _token,
        address _spender,
        uint _amount
    ) private {
        IERC20(_token).safeIncreaseAllowance(_spender, _amount);
    }
}
