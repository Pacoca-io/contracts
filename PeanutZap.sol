// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakePair.sol";

contract PeanutZap is Ownable {
    using SafeMath for uint;
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

    constructor (address _treasury, address _owner) public {
        treasury = _treasury;
        transferOwnership(_owner);
    }

    function zapToken(
        IPancakeRouter02 _router,
        address[] calldata _pathToToken0,
        address[] calldata _pathToToken1,
        address _inputToken,
        IPancakePair _outputToken,
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

        IERC20(_inputToken).transferFrom(msg.sender, address(this), _inputTokenAmount);

        uint swapInputAmount = _getBalance(_inputToken).sub(initialBalances.inputToken).div(2);

        if (_inputToken != tokens.token0)
            _swap(_router, swapInputAmount, _minToken0, _pathToToken0);

        if (_inputToken != tokens.token1)
            _swap(_router, swapInputAmount, _minToken1, _pathToToken1);

        _router.addLiquidity(
            tokens.token0,
            tokens.token1,
            _getBalance(tokens.token0).sub(initialBalances.token0),
            _getBalance(tokens.token1).sub(initialBalances.token1),
            _minToken0,
            _minToken1,
            msg.sender,
            block.timestamp
        );
    }

    function unZapToken(
        IPancakeRouter02 _router,
        address[] calldata _pathFromToken0,
        address[] calldata _pathFromToken1,
        IPancakePair _inputToken,
        address _outputToken,
        uint _inputTokenAmount,
        uint _minOutputToken0,
        uint _minOutputToken1
    ) public {
        Tokens memory tokens = _getTokens(_inputToken);

        InitialBalances memory initialBalances = InitialBalances(
            _getBalance(tokens.token0),
            _getBalance(tokens.token1),
            _inputToken.balanceOf(address(this))
        );

        uint initialOutputTokenBalance = _getBalance(_outputToken);

        _inputToken.transferFrom(msg.sender, address(this), _inputTokenAmount);

        // TODO support fee on transfer tokens
        _router.removeLiquidity(
            tokens.token0,
            tokens.token1,
            _inputToken.balanceOf(address(this)).sub(initialBalances.inputToken),
            0, // TODO maybe care about output amounts
            0, // TODO maybe care about output amounts
            address(this),
            block.timestamp
        );

        if (_outputToken != tokens.token0)
            _swapTo(
                _router,
                _getBalance(tokens.token0).sub(initialBalances.token0),
                _minOutputToken0,
                _pathFromToken0,
                msg.sender
            );

        if (_outputToken != tokens.token1)
            _swapTo(
                _router,
                _getBalance(tokens.token1).sub(initialBalances.token1),
                _minOutputToken1,
                _pathFromToken1,
                msg.sender
            );

        uint finalOutputTokenBalance = _getBalance(_outputToken);

        if (finalOutputTokenBalance != initialOutputTokenBalance)
            IERC20(_outputToken).transferFrom(
                address(this),
                msg.sender,
                finalOutputTokenBalance.sub(initialOutputTokenBalance)
            );
    }

    function _getTokens(
        IPancakePair _lp
    ) private view returns (
        Tokens memory tokens
    ) {
        return Tokens(
            _lp.token0(),
            _lp.token1()
        );
    }

    function _swap(
        IPancakeRouter02 _router,
        uint _amountIn,
        uint _amountOutMin,
        address[] memory _path
    ) private {
        _router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            _amountOutMin,
            _path,
            address(this),
            block.timestamp
        );
    }

    function _swapTo(
        IPancakeRouter02 _router,
        uint _amountIn,
        uint _amountOutMin,
        address[] memory _path,
        address _to
    ) private {
        _router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            _amountOutMin,
            _path,
            _to,
            block.timestamp
        );
    }

    function _getBalance(address _token) private view returns (uint) {
        return IERC20(_token).balanceOf(address(this));
    }

    function collectDust(address _token) public {
        IERC20 token = IERC20(_token);

        token.transfer(treasury, token.balanceOf(address(this)));
    }

    function collectDustMultiple(address[] calldata _tokens) public {
        for (uint index = 0; index < _tokens.length; ++index) {
            collectDust(_tokens[index]);
        }
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
}
