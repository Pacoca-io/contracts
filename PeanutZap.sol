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

interface IwNative is IERC20 {
    function deposit() external payable;

    function withdraw(uint) external;
}

contract PeanutZap is OwnableUpgradeable, PeanutRouter {
    using SafeERC20 for IERC20;

    struct Tokens {
        address token0;
        address token1;
    }

    struct InitialBalances {
        uint token0;
        uint token1;
        uint inputToken;
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
        IPancakeRouter02 _router,
        address[] calldata _pathToToken0,
        address[] calldata _pathToToken1,
        address _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minToken0,
        uint _minToken1
    ) public {
        Tokens memory tokens = _getTokens(_outputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(tokens.token0),
            _getBalance(tokens.token1),
            _getBalance(_inputToken)
        );

        IERC20(_inputToken).safeTransferFrom(msg.sender, address(this), _inputTokenAmount);

        _zap(
            _router,
            _pathToToken0,
            _pathToToken1,
            _inputToken,
            _minToken0,
            _minToken1,
            tokens,
            initialBalances
        );
    }

    function zapNative(
        IPancakeRouter02 _router,
        address[] calldata _pathToToken0,
        address[] calldata _pathToToken1,
        address _outputToken,
        uint _minToken0,
        uint _minToken1
    ) external payable {
        Tokens memory tokens = _getTokens(_outputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(tokens.token0),
            _getBalance(tokens.token1),
            _getBalance(address(wNATIVE))
        );

        // TODO check if this throws or returns false in case of .deposit() failing
        wNATIVE.deposit{value : msg.value}();

        _zap(
            _router,
            _pathToToken0,
            _pathToToken1,
            address(wNATIVE),
            _minToken0,
            _minToken1,
            tokens,
            initialBalances
        );
    }

    function _zap(
        IPancakeRouter02 _router,
        address[] calldata _pathToToken0,
        address[] calldata _pathToToken1,
        address _inputToken,
        uint _minToken0,
        uint _minToken1,
        Tokens memory _tokens,
        InitialBalances memory _initialBalances
    ) private {
        uint swapInputAmount = (_getBalance(_inputToken) - _initialBalances.inputToken) / 2;

        if (_inputToken != _tokens.token0)
            _swap(_router, swapInputAmount, _minToken0, _pathToToken0, address(this));

        if (_inputToken != _tokens.token1)
            _swap(_router, swapInputAmount, _minToken1, _pathToToken1, address(this));

        _addLiquidity(
            _router,
            _tokens.token0,
            _tokens.token1,
            _getBalance(_tokens.token0) - _initialBalances.token0,
            _getBalance(_tokens.token1) - _initialBalances.token1,
            _minToken0,
            _minToken1,
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
        Tokens memory tokens = _getTokens(_inputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(tokens.token0),
            _getBalance(tokens.token1),
            _getBalance(_inputToken)
        );

        IERC20(_inputToken).safeTransferFrom(msg.sender, address(this), _inputTokenAmount);

        // TODO support fee on transfer tokens
        _removeLiquidity(
            _router,
            tokens.token0,
            tokens.token1,
            _inputToken,
            _getBalance(_inputToken) - initialBalances.inputToken,
            0, // TODO maybe care about output amounts
            0 // TODO maybe care about output amounts
        );

        if (_outputToken != tokens.token0)
            _swap(
                _router,
                _getBalance(tokens.token0) - initialBalances.token0,
                _minOutputToken0,
                _pathFromToken0,
                _to
            );

        if (_outputToken != tokens.token1)
            _swap(
                _router,
                _getBalance(tokens.token1) - initialBalances.token1,
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
        Tokens memory tokens  = _getTokens(_tokens[0]);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(tokens.token0),
            _getBalance(tokens.token1),
            _getBalance(_tokens[0])
        );

        _receiveUserTokens(_tokens[0], _inputTokenAmount, _signatureData);

        _removeLiquidity(
            _router,
            tokens.token0,
            tokens.token1,
            _tokens[0],
            _getBalance(_tokens[0]) - initialBalances.inputToken,
            0, // TODO maybe care about output amounts
            0 // TODO maybe care about output amounts
        );


        if (_tokens[1] != tokens.token0)
            _swap(
                _router,
                _getBalance(tokens.token0) - initialBalances.token0,
                _minOutputs[0],
                _pathFromTokens[0],
                _to
            );

        if (_tokens[1] != tokens.token1)
            _swap(
                _router,
                _getBalance(tokens.token1) - initialBalances.token1,
                _minOutputs[1],
                _pathFromTokens[1],
                _to
            );
    }

    function _receiveUserTokens(address _token, uint _inputTokenAmount, bytes calldata _signatureData) internal {
        (uint8 v, bytes32 r, bytes32 s, uint8 deadline) = abi.decode(_signatureData, (uint8, bytes32, bytes32, uint));

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

    function _getTokens(
        address _lp
    ) private view returns (
        Tokens memory tokens
    ) {
        IPancakePair lp = IPancakePair(_lp);

        return Tokens(lp.token0(), lp.token1());
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
