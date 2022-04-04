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
import "./interfaces/IPancakePair.sol";
import "./helpers/PeanutRouter.sol";
import "./interfaces/IwNative.sol";

contract PeanutZap is OwnableUpgradeable, PeanutRouter {
    using SafeERC20 for IERC20;

    struct Pair {
        address token0;
        address token1;
    }

    struct InitialBalances {
        uint token0;
        uint token1;
        uint inputToken;
    }

    struct ZapInfo {
        IPancakeRouter02 router;
        address[] pathFromToken0;
        address[] pathFromToken1;
        uint minToken0;
        uint minToken1;
    }

    struct UnZapInfo {
        IPancakeRouter02 router;
        address[] pathToToken0;
        address[] pathToToken1;
        uint minToken0;
        uint minToken1;
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
            _swap(zapInfo.router, swapInputAmount, zapInfo.minToken0, zapInfo.pathFromToken0, address(this));

        if (_inputToken != _pair.token1)
            _swap(zapInfo.router, swapInputAmount, zapInfo.minToken1, zapInfo.pathFromToken1, address(this));

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
        IPancakeRouter02 _router,
        address[] calldata _pathFromToken0,
        address[] calldata _pathFromToken1,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputToken0,
        uint _minOutputToken1,
        address _to
    ) public {
        uint initialOutputTokenBalance = _getBalance(_outputToken);

        _unZapToken(
            _router,
            _pathFromToken0,
            _pathFromToken1,
            _inputToken,
            _outputToken,
            _inputTokenAmount,
            _minOutputToken0,
            _minOutputToken1,
            _to
        );

        uint finalOutputTokenBalance = _getBalance(_outputToken);

        if (finalOutputTokenBalance != initialOutputTokenBalance)
            IERC20(_outputToken).safeTransfer(
                msg.sender,
                finalOutputTokenBalance - initialOutputTokenBalance
            );
    }

    function unZapTokenWithPermit(
        IPancakeRouter02 _router,
        address[][] calldata _pathFromTokens,
        address[2] memory _tokens,
        uint _inputTokenAmount,
        uint[2] calldata _minOutputs,
        address _to,
        bytes calldata _signatureData
    ) external {
        uint initialOutputTokenBalance = _getBalance(_tokens[1]);

        _unZapTokenWithPermit(
            _router,
            _pathFromTokens,
            _tokens,
            _inputTokenAmount,
            _minOutputs,
            _to,
            _signatureData
        );

        uint finalOutputTokenBalance = _getBalance(_tokens[1]);

        if (finalOutputTokenBalance != initialOutputTokenBalance)
            IERC20(_tokens[1]).safeTransfer(
                msg.sender,
                _getBalance(_tokens[1]) - initialOutputTokenBalance
            );
    }

    function unZapNativeWithPermit(
        IPancakeRouter02 _router,
        address[][] calldata _pathFromTokens,
        address _inputToken,
        uint _inputTokenAmount,
        uint[2] calldata _minOutputs,
        address payable _to,
        bytes calldata _signatureData
    ) external {
        address outputToken = address(wNATIVE);
        uint initialOutputTokenBalance = _getBalance(outputToken);

        _unZapTokenWithPermit(
            _router,
            _pathFromTokens,
            [_inputToken, outputToken],
            _inputTokenAmount,
            _minOutputs,
            address(this),
            _signatureData
        );

        uint finalOutputTokenBalance = _getBalance(outputToken);

        if (finalOutputTokenBalance != initialOutputTokenBalance) {
            uint amount = finalOutputTokenBalance - initialOutputTokenBalance;

            wNATIVE.withdraw(amount);

            // TODO check if safe
            _to.transfer(amount);
        }
    }

    // TODO maybe consider only the output of desired token
    function unZapNative(
        IPancakeRouter02 _router,
        address[] calldata _pathFromToken0,
        address[] calldata _pathFromToken1,
        address _inputToken,
        uint _inputTokenAmount,
        uint _minOutputToken0,
        uint _minOutputToken1,
        address payable _to
    ) external {
        address outputToken = address(wNATIVE);
        uint initialOutputTokenBalance = _getBalance(outputToken);

        _unZapToken(
            _router,
            _pathFromToken0,
            _pathFromToken1,
            _inputToken,
            outputToken,
            _inputTokenAmount,
            _minOutputToken0,
            _minOutputToken1,
            address(this)
        );

        uint finalOutputTokenBalance = _getBalance(outputToken);

        if (finalOutputTokenBalance != initialOutputTokenBalance) {
            uint amount = finalOutputTokenBalance - initialOutputTokenBalance;

            wNATIVE.withdraw(amount);

            // TODO check if safe
            _to.transfer(amount);
        }
    }

    // TODO maybe consider only the output of desired token
    function _unZapToken(
        IPancakeRouter02 _router,
        address[] calldata _pathFromToken0,
        address[] calldata _pathFromToken1,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputToken0,
        uint _minOutputToken1,
        address _to
    ) public {
        Pair memory pair = _getPairInfo(_inputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(_inputToken)
        );

        IERC20(_inputToken).safeTransferFrom(msg.sender, address(this), _inputTokenAmount);

        // TODO support fee on transfer tokens
        _removeLiquidity(
            _router,
            pair.token0,
            pair.token1,
            _inputToken,
            _getBalance(_inputToken) - initialBalances.inputToken,
            0, // TODO maybe care about output amounts
            0 // TODO maybe care about output amounts
        );

        if (_outputToken != pair.token0)
            _swap(
                _router,
                _getBalance(pair.token0) - initialBalances.token0,
                _minOutputToken0,
                _pathFromToken0,
                _to
            );

        if (_outputToken != pair.token1)
            _swap(
                _router,
                _getBalance(pair.token1) - initialBalances.token1,
                _minOutputToken1,
                _pathFromToken1,
                _to
            );
    }

    function _unZapTokenWithPermit(
        IPancakeRouter02 _router,
        address[][] calldata _pathFromTokens,
        address[2] memory _tokens,
        uint _inputTokenAmount,
        uint[2] calldata _minOutputs,
        address _to,
        bytes calldata _signatureData
    ) public {
        Pair memory pair = _getPairInfo(_tokens[0]);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(pair.token0),
            _getBalance(pair.token1),
            _getBalance(_tokens[0])
        );

        _receiveUserTokens(_tokens[0], _inputTokenAmount, _signatureData);

        _removeLiquidity(
            _router,
            pair.token0,
            pair.token1,
            _tokens[0],
            _getBalance(_tokens[0]) - initialBalances.inputToken,
            0, // TODO maybe care about output amounts
            0 // TODO maybe care about output amounts
        );


        if (_tokens[1] != pair.token0)
            _swap(
                _router,
                _getBalance(pair.token0) - initialBalances.token0,
                _minOutputs[0],
                _pathFromTokens[0],
                _to
            );

        if (_tokens[1] != pair.token1)
            _swap(
                _router,
                _getBalance(pair.token1) - initialBalances.token1,
                _minOutputs[1],
                _pathFromTokens[1],
                _to
            );
    }

    function _receiveUserTokens(address _token, uint _inputTokenAmount, bytes calldata _signatureData) internal {
        (uint8 v, bytes32 r, bytes32 s, uint deadline) = abi.decode(_signatureData, (uint8, bytes32, bytes32, uint));

        IPancakePair(_token).permit(
            msg.sender,
            address(this),
            _inputTokenAmount,
            deadline,
            v,
            r,
            s
        );

        IERC20(_token).safeTransferFrom(
            msg.sender,
            address(this),
            _inputTokenAmount
        );
    }

    function _getPairInfo(
        address _pair
    ) private view returns (
        Pair memory tokens
    ) {
        IPancakePair pair = IPancakePair(_pair);

        return Pair(pair.token0(), pair.token1());
    }

    function _getBalance(address _token) private view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
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
