/**
                                                         __
     _____      __      ___    ___     ___     __       /\_\    ___
    /\ "__`\  /"__`\   /"___\ / __`\  /"___\ /"__`\     \/\ \  / __`\
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
import "@openzeppelin/contracts-upgradeable-v4/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./libraries/UniswapV2Library.sol";
import "./interfaces/IPancakeRouter02.sol";

import "hardhat/console.sol";

contract PeanutDCA is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct PositionInfo {
        uint pid;
        uint amount;
        uint swaps;
        uint rate;
        uint firstSwap;
        uint finalSwap;
        uint lastUpdatedAt; // swap number where last updated
    }

    struct PoolInfo {
        address inputToken;
        address outputToken;
        address router;
        address[] path;
        address factory;
        uint nextSwapAmount;
        uint performedSwaps;
    }

    // user => positionId => position
    // mapping(address => mapping(uint => PositionInfo)) internal _positionInfo;

    // user => position
    mapping(address => PositionInfo[]) internal _positionInfo;

    // pid => swap number => delta
    mapping(uint => mapping(uint => uint)) internal _poolDelta;

    PoolInfo[] public poolInfo;

    function initialize(address _owner) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        transferOwnership(_owner);
    }


    //  --------------------
    // | EXTERNAL FUNCTIONS |
    //  --------------------

    function createPool(
        address _inputToken,
        address _outputToken,
        address _router,
        address _factory,
        address[] calldata _path
    ) external onlyOwner {
        poolInfo.push(PoolInfo({
            inputToken: _inputToken,
            outputToken: _outputToken,
            router: _router,
            factory: _factory,
            path: _path,
            nextSwapAmount: 0,
            performedSwaps: 0
        }));
    }

    function createPosition(uint _pid, uint _amount, uint _swaps) external nonReentrant {
        require(_poolExist(_pid), "PeanutDCA:: invalid pid");
        require(_amount > 0, "PeanutDCA:: invalid amount");
        require(_swaps > 0, "PeanutDCA:: invalid swaps");

        PoolInfo memory pool = poolInfo[_pid];

        uint rate = _calculateRate(_amount, _swaps);
        uint finalSwap = pool.performedSwaps + _swaps;

        _increasePoolSwapAmount(_pid, rate);
        _increasePoolDelta(_pid, rate, finalSwap + 1);

        _positionInfo[msg.sender].push(_buildPosition(
            _amount,
            _swaps,
            rate,
            finalSwap,
            pool.performedSwaps,
            _pid
        ));

        IERC20Upgradeable(pool.inputToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function getPosition(address _user, uint _positionId) external view returns (PositionInfo memory) {
        return _positionInfo[_user][_positionId];
    }

    function balanceOf(address _token) external view returns (uint balance) {
        return IERC20Upgradeable(_token).balanceOf(address(this));
    }


    //  ------------------
    // | PUBLIC FUNCTIONS |
    //  ------------------

    function poolLength() public view returns (uint) {
        return poolInfo.length;
    }


    //  --------------------
    // | INTERNAL FUNCTIONS |
    //  --------------------

    function _buildPosition(
        uint _amount,
        uint _swaps,
        uint _rate,
        uint _finalSwap,
        uint _firstSwap,
        uint _pid
    ) internal view returns (PositionInfo memory position) {
        position = PositionInfo({
            amount: _amount,
            swaps: _swaps,
            rate: _rate,
            pid: _pid,
            finalSwap: _finalSwap,
            firstSwap: _firstSwap,
            lastUpdatedAt: 0
        });
    }

    function _increasePoolSwapAmount(uint _pid, uint _rate) internal {
        poolInfo[_pid].nextSwapAmount += _rate;
    }

    function _increasePoolDelta(uint _pid, uint _finalSwap, uint _rate) internal {
        _poolDelta[_pid][_finalSwap] += _rate;
    }

    function _decreasePoolSwapAmount(uint _pid, uint _rate) internal {
        poolInfo[_pid].nextSwapAmount -= _rate;
    }

    function _decreasePoolDelta(uint _pid, uint _swapOffset, uint _rate) internal {
        _poolDelta[_pid][_swapOffset] -= _rate;
    }

    function _poolExist(uint _pid) internal view returns (bool) {
        return _pid < poolLength();
    }

    function _calculateRate(uint _amount, uint _swaps) internal pure returns(uint) {
        return _amount / _swaps;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

}

