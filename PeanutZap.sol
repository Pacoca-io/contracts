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
import "@openzeppelin/contracts-upgradeable-v4/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-v4/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IwNative.sol";
import "./interfaces/IPeanutZap.sol";
import "./helpers/PeanutRouter.sol";
import "./helpers/ZapHelpers.sol";
import "./helpers/Permit.sol";

contract PeanutZap is IPeanutZap, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, ZapHelpers {
    using SafeERC20 for IERC20;

    address public treasury;
    IwNative public wNATIVE;

    function initialize(
        address _treasury,
        address _owner,
        address _wNative
    ) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(_owner);

        treasury = _treasury;
        wNATIVE = IwNative(_wNative);
    }

    function zapToken(
        ZapInfo calldata _zapInfo,
        address _inputToken,
        uint _inputTokenAmount
    ) external nonReentrant {
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
    ) external payable nonReentrant {
        Pair memory pair = _getPairInfo(_zapInfo.outputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(address(wNATIVE))
        );

        wNATIVE.deposit{value : msg.value}();

        _zap(
            _zapInfo,
            address(wNATIVE),
            pair,
            initialBalances
        );
    }

    // TODO reentrancy guard
    function _zap(
        ZapInfo calldata _zapInfo,
        address _inputToken,
        Pair memory _pair,
        InitialBalances memory _initialBalances
    ) private {
        require(_zapInfo.pathToToken0[0] == _zapInfo.pathToToken1[0], "Zap:: Invalid paths");

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
    ) external nonReentrant {
        _unZapToken(_unZapInfo, _outputToken);
    }

    function unZapTokenWithPermit(
        UnZapInfo calldata _unZapInfo,
        address _outputToken,
        bytes calldata _signatureData
    ) external nonReentrant {
        Permit.approve(
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

    function unZapNative(UnZapInfo calldata _unZapInfo) external nonReentrant {
        _unZapNative(_unZapInfo);
    }

    function unZapNativeWithPermit(
        UnZapInfo calldata _unZapInfo,
        bytes calldata _signatureData
    ) external nonReentrant {
        Permit.approve(
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

        (uint amount0, uint amount1) = _removeLiquidity(
            pair,
            _unZapInfo.router,
            _unZapInfo.inputToken,
            _unZapInfo.inputTokenAmount
        );

        if (_outputToken != pair.token0)
            PeanutRouter.swap(
                _unZapInfo.router,
                amount0,
                0,
                _unZapInfo.pathFromToken0
            );

        if (_outputToken != pair.token1)
            PeanutRouter.swap(
                _unZapInfo.router,
                amount1,
                0,
                _unZapInfo.pathFromToken1
            );
    }

    function _removeLiquidity(
        Pair memory _pair,
        IPancakeRouter02 _router,
        address _inputToken,
        uint _inputTokenAmount
    ) private returns (
        uint amount0,
        uint amount1
    ) {
        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(_pair.token0),
            _getBalance(_pair.token1),
            _getBalance(_inputToken)
        );

        IERC20(_inputToken).safeTransferFrom(
            msg.sender,
            address(this),
            _inputTokenAmount
        );

        PeanutRouter.removeLiquidity(
            _router,
            _pair.token0,
            _pair.token1,
            _inputToken,
            _getBalance(_inputToken) - initialBalances.inputToken,
            0,
            0
        );

        amount0 = _getBalance(_pair.token0) - initialBalances.token0;
        amount1 = _getBalance(_pair.token1) - initialBalances.token1;
    }

    function zapPair(ZapPairInfo calldata _zapPairInfo) external nonReentrant {
        Pair memory inputPair = _getPairInfo(_zapPairInfo.inputToken);
        Pair memory outputPair = _getPairInfo(_zapPairInfo.outputToken);

        uint initialBalanceTokenA = _getBalance(outputPair.token0);
        uint initialBalanceTokenB = _getBalance(outputPair.token1);

        (uint amount0, uint amount1) = _removeLiquidity(
            inputPair,
            _zapPairInfo.routerIn,
            _zapPairInfo.inputToken,
            _zapPairInfo.inputTokenAmount
        );

        if (_zapPairInfo.pathFromToken0.length > 0) {
            require(
                _zapPairInfo.pathFromToken0[0] == inputPair.token0,
                "zapPair::Invalid pathFromToken0"
            );

            PeanutRouter.swap(
                _zapPairInfo.routerSwap,
                amount0,
                0,
                _zapPairInfo.pathFromToken0
            );
        }

        if (_zapPairInfo.pathFromToken1.length > 0) {
            require(
                _zapPairInfo.pathFromToken1[0] == inputPair.token1,
                "zapPair::Invalid pathFromToken1"
            );

            PeanutRouter.swap(
                _zapPairInfo.routerSwap,
                amount1,
                0,
                _zapPairInfo.pathFromToken1
            );
        }

        PeanutRouter.addLiquidity(
            _zapPairInfo.routerOut,
            outputPair.token0,
            outputPair.token1,
            _getBalance(outputPair.token0) - initialBalanceTokenA,
            _getBalance(outputPair.token1) - initialBalanceTokenB,
            _zapPairInfo.minTokenA,
            _zapPairInfo.minTokenB,
            msg.sender
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

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
