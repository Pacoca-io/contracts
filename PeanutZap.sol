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

import "@openzeppelin/contracts-upgradeable-v4/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-v4/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IwNative.sol";
import "./interfaces/IPeanutZap.sol";
import "./helpers/PeanutRouter.sol";
import "./helpers/ZapHelpers.sol";

contract PeanutZap is IPeanutZap, OwnableUpgradeable, ZapHelpers {
    using SafeERC20 for IERC20;

    address public treasury;
    IwNative public wNATIVE;

    function initialize(
        address _treasury,
        address _owner,
        address _wNative
    ) public initializer {
        __Ownable_init();
        transferOwnership(_owner);

        treasury = _treasury;
        wNATIVE = IwNative(_wNative);
    }

    function zapToken(
        ZapInfo calldata _zapInfo,
        address _inputToken,
        uint _inputTokenAmount
    ) public {
        Pair memory pair = _getPairInfo(_zapInfo.outputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(_inputToken)
        );

        IERC20(_inputToken).safeTransferFrom(msg.sender, address(this), _inputTokenAmount);

        _zap(
            _zapInfo,
            _inputToken,
            pair,
            initialBalances
        );
    }

    function zapNative(
        ZapInfo calldata _zapInfo
    ) external payable {
        Pair memory pair = _getPairInfo(_zapInfo.outputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(address(wNATIVE))
        );

        // TODO check if this throws or returns false in case of .deposit() failing
        wNATIVE.deposit{value : msg.value}();

        _zap(
            _zapInfo,
            address(wNATIVE),
            pair,
            initialBalances
        );
    }

    function _zap(
        ZapInfo calldata _zapInfo,
        address _inputToken,
        Pair memory _pair,
        InitialBalances memory _initialBalances
    ) private {
        uint swapInputAmount = (_getBalance(_inputToken) - _initialBalances.inputToken) / 2;

        if (_inputToken != _pair.token0)
            PeanutRouter.swap(_zapInfo.router, swapInputAmount, _zapInfo.minToken0, _zapInfo.pathToToken0);

        if (_inputToken != _pair.token1)
            PeanutRouter.swap(_zapInfo.router, swapInputAmount, _zapInfo.minToken1, _zapInfo.pathToToken1);

        PeanutRouter.addLiquidity(
            _zapInfo.router,
            _pair.token0,
            _pair.token1,
            _getBalance(_pair.token0) - _initialBalances.token0,
            _getBalance(_pair.token1) - _initialBalances.token1,
            _zapInfo.minToken0,
            _zapInfo.minToken1,
            msg.sender
        );
    }

    function unZapToken(
        UnZapInfo calldata _unZapInfo,
        address _outputToken
    ) external {
        _unZapToken(_unZapInfo, _outputToken);
    }

    function unZapTokenWithPermit(
        UnZapInfo calldata _unZapInfo,
        address _outputToken,
        bytes calldata _signatureData
    ) external {
        _approveUsingPermit(
            _unZapInfo.inputToken,
            _unZapInfo.inputTokenAmount,
            _signatureData
        );

        _unZapToken(_unZapInfo, _outputToken);
    }

    function _unZapToken(
        UnZapInfo calldata _unZapInfo,
        address _outputToken
    ) private {
        uint initialOutputTokenBalance = _getBalance(_outputToken);

        _unZap(_unZapInfo, _outputToken);

        IERC20(_outputToken).safeTransfer(
            msg.sender,
            _calculateUnZapProfit(
                initialOutputTokenBalance,
                _getBalance(_outputToken),
                _unZapInfo.minOutputTokenAmount
            )
        );
    }

    function unZapNative(UnZapInfo calldata _unZapInfo) external {
        _unZapNative(_unZapInfo);
    }

    function unZapNativeWithPermit(
        UnZapInfo calldata _unZapInfo,
        bytes calldata _signatureData
    ) external {
        _approveUsingPermit(
            _unZapInfo.inputToken,
            _unZapInfo.inputTokenAmount,
            _signatureData
        );

        _unZapNative(_unZapInfo);
    }

    function _unZapNative(UnZapInfo calldata _unZapInfo) private {
        address outputToken = address(wNATIVE);
        uint initialOutputTokenBalance = _getBalance(outputToken);

        _unZap(_unZapInfo, outputToken);

        uint profit = _calculateUnZapProfit(
            initialOutputTokenBalance,
            _getBalance(outputToken),
            _unZapInfo.minOutputTokenAmount
        );

        wNATIVE.withdraw(profit);

        payable(msg.sender).transfer(profit);
    }

    function _unZap(
        UnZapInfo calldata _unZapInfo,
        address _outputToken
    ) private {
        Pair memory pair = _getPairInfo(_unZapInfo.inputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(_unZapInfo.inputToken)
        );

        IERC20(_unZapInfo.inputToken).safeTransferFrom(msg.sender, address(this), _unZapInfo.inputTokenAmount);

        PeanutRouter.removeLiquidity(
            _unZapInfo.router,
            pair.token0,
            pair.token1,
            _unZapInfo.inputToken,
            _getBalance(_unZapInfo.inputToken) - initialBalances.inputToken,
            0,
            0
        );

        if (_outputToken != pair.token0)
            PeanutRouter.swap(
                _unZapInfo.router,
                _getBalance(pair.token0) - initialBalances.token0,
                0,
                _unZapInfo.pathFromToken0
            );

        if (_outputToken != pair.token1)
            PeanutRouter.swap(
                _unZapInfo.router,
                _getBalance(pair.token1) - initialBalances.token1,
                0,
                _unZapInfo.pathFromToken1
            );
    }

    function collectDust(address _token) public onlyOwner {
        IERC20 token = IERC20(_token);

        token.safeTransfer(treasury, token.balanceOf(address(this)));
    }

    function collectDustMultiple(address[] calldata _tokens) external onlyOwner {
        for (uint index = 0; index < _tokens.length; ++index) {
            collectDust(_tokens[index]);
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    receive() external payable {}
}
