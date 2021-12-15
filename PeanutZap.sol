// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakePair.sol";

contract PeanutZap is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public treasury;

    constructor (address _treasury, address _owner) public {
        treasury = _treasury;
        transferOwnership(_owner);
    }

    function zapToken(
        IPancakeRouter02 _router,
        address[] calldata _pathToToken0,
        address[] calldata _pathToToken1,
        IERC20 _inputToken,
        IPancakePair _outputToken,
        uint _inputTokenAmount,
        uint _minToken0,
        uint _minToken1
    ) public {
        uint initialBalanceToken0 = _getBalance(_outputToken.token0());
        uint initialBalanceToken1 = _getBalance(_outputToken.token1());
        uint swapInputAmount = _inputTokenAmount.div(2);

        _inputToken.transferFrom(msg.sender, address(this), _inputTokenAmount);

        if (address(_inputToken) != _outputToken.token0())
            _router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                swapInputAmount,
                _minToken0,
                _pathToToken0,
                address(this),
                block.timestamp
            );

        if (address(_inputToken) != _outputToken.token1())
            _router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                swapInputAmount,
                _minToken1,
                _pathToToken1,
                address(this),
                block.timestamp
            );

        _router.addLiquidity(
            _outputToken.token0(),
            _outputToken.token1(),
            _getBalance(_outputToken.token0()).sub(initialBalanceToken0),
            _getBalance(_outputToken.token1()).sub(initialBalanceToken1),
            _minToken0,
            _minToken1,
            msg.sender,
            block.timestamp
        );
    }

    function zapETH(
        IPancakeRouter02 _router,
        address[] calldata _pathToToken0,
        address[] calldata _pathToToken1,
        IERC20 _inputToken,
        IPancakePair _outputToken,
        uint _inputTokenAmount,
        uint _minToken0,
        uint _minToken1
    ) public {

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
