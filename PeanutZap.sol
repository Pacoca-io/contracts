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
import "./helpers/PeanutRouter.sol";
import "./interfaces/IwNative.sol";
import "./helpers/ZapHelpers.sol";

contract PeanutZap is OwnableUpgradeable, PeanutRouter, ZapHelpers {
    using SafeERC20 for IERC20;

    struct InitialBalances {
        uint token0;
        uint token1;
        uint inputToken;
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
        uint minToken0;
        uint minToken1;
        uint minOutputToken;
    }

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
        bytes calldata _zapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount
    ) public {
        Pair memory pair = _getPairInfo(_outputToken);

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
        bytes calldata _zapInfo,
        address _outputToken
    ) external payable {
        Pair memory pair = _getPairInfo(_outputToken);

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
        bytes calldata _zapInfo,
        address _inputToken,
        Pair memory _pair,
        InitialBalances memory _initialBalances
    ) private {
        ZapInfo memory zapInfo = abi.decode(_zapInfo, (ZapInfo));
        uint swapInputAmount = (_getBalance(_inputToken) - _initialBalances.inputToken) / 2;

        if (_inputToken != _pair.token0)
            _swap(zapInfo.router, swapInputAmount, zapInfo.minToken0, zapInfo.pathToToken0, address(this));

        if (_inputToken != _pair.token1)
            _swap(zapInfo.router, swapInputAmount, zapInfo.minToken1, zapInfo.pathToToken1, address(this));

        _addLiquidity(
            zapInfo.router,
            _pair.token0,
            _pair.token1,
            _getBalance(_pair.token0) - _initialBalances.token0,
            _getBalance(_pair.token1) - _initialBalances.token1,
            zapInfo.minToken0,
            zapInfo.minToken1,
            msg.sender
        );
    }

    function unZapToken(
        bytes calldata _unZapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount
    ) external {
        _unZapToken(
            _unZapInfo,
            _inputToken,
            _outputToken,
            _inputTokenAmount,
            _minOutputTokenAmount
        );
    }

    function unZapTokenWithPermit(
        bytes calldata _unZapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount,
        bytes calldata _signatureData
    ) external {
        _approveUsingPermit(
            _inputToken,
            _inputTokenAmount,
            _signatureData
        );

        _unZapToken(
            _unZapInfo,
            _inputToken,
            _outputToken,
            _inputTokenAmount,
            _minOutputTokenAmount
        );
    }

    function _unZapToken(
        bytes calldata _unZapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount
    ) private {
        uint initialOutputTokenBalance = _getBalance(_outputToken);

        _unZap(
            _unZapInfo,
            _inputToken,
            _outputToken,
            _inputTokenAmount
        );

        IERC20(_outputToken).safeTransfer(
            msg.sender,
            _calculateUnZapProfit(
                initialOutputTokenBalance,
                _getBalance(_outputToken),
                _minOutputTokenAmount
            )
        );
    }

    function unZapNative(
        bytes calldata _unZapInfo,
        address _inputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount
    ) external {
        _unZapNative(
            _unZapInfo,
            _inputToken,
            _inputTokenAmount,
            _minOutputTokenAmount
        );
    }

    function unZapNativeWithPermit(
        bytes calldata _unZapInfo,
        address _inputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount,
        bytes calldata _signatureData
    ) external {
        _approveUsingPermit(
            _inputToken,
            _inputTokenAmount,
            _signatureData
        );

        _unZapNative(
            _unZapInfo,
            _inputToken,
            _inputTokenAmount,
            _minOutputTokenAmount
        );
    }

    function _unZapNative(
        bytes calldata _unZapInfo,
        address _inputToken,
        uint _inputTokenAmount,
        uint _minOutputTokenAmount
    ) private {
        address outputToken = address(wNATIVE);
        uint initialOutputTokenBalance = _getBalance(outputToken);

        _unZap(
            _unZapInfo,
            _inputToken,
            outputToken,
            _inputTokenAmount
        );

        uint profit = _calculateUnZapProfit(
            initialOutputTokenBalance,
            _getBalance(outputToken),
            _minOutputTokenAmount
        );

        wNATIVE.withdraw(profit);

        payable(msg.sender).transfer(profit);
    }

    function _unZap(
        bytes calldata _unZapInfo,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount
    ) public {
        UnZapInfo memory unZapInfo = abi.decode(_unZapInfo, (UnZapInfo));
        Pair memory pair = _getPairInfo(_inputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(_inputToken)
        );

        IERC20(_inputToken).safeTransferFrom(msg.sender, address(this), _inputTokenAmount);

        // TODO support fee on transfer tokens
        _removeLiquidity(
            unZapInfo.router,
            pair.token0,
            pair.token1,
            _inputToken,
            _getBalance(_inputToken) - initialBalances.inputToken,
            0,
            0
        );

        if (_outputToken != pair.token0)
            _swap(
                unZapInfo.router,
                _getBalance(pair.token0) - initialBalances.token0,
                unZapInfo.minToken0,
                unZapInfo.pathFromToken0,
                address(this)
            );

        if (_outputToken != pair.token1)
            _swap(
                unZapInfo.router,
                _getBalance(pair.token1) - initialBalances.token1,
                unZapInfo.minToken1,
                unZapInfo.pathFromToken1,
                address(this)
            );
    }

    function collectDust(address _token) public {
        IERC20 token = IERC20(_token);

        token.safeTransfer(treasury, token.balanceOf(address(this)));
    }

    function collectDustMultiple(address[] calldata _tokens) public {
        for (uint index = 0; index < _tokens.length; ++index) {
            collectDust(_tokens[index]);
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    receive() external payable {}
}
