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

import "./interfaces/IPancakeRouter02.sol";
import "./helpers/PeanutHelpers.sol";

import "hardhat/console.sol";

contract PeanutDCA is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct PoolInfo {
        address inputToken;
        address outputToken;
        address router;
        address[] path;
        uint totalTokensInPool;
        uint totalAmountToSwap;
        uint lastSwap;
    }

    struct UserInfo {
        uint stake;
        uint totalAmountToSwap;
        uint amountToSwap;
        uint rewardDebt; // TODO: rewardDebt should be on the pool that the user swapped to
        uint lastDepositTime;
    }

    // token address => user address => user info
    mapping(address => mapping(address => UserInfo)) public userInfo;
    PoolInfo[] public poolInfo;

    event Deposit(address indexed user, address indexed token, uint amount);
    event Withdraw(address indexed user, address indexed token, uint amount);
    event CreateStrategy(uint stake, uint amout, address indexed token);

    function initialize(
        address _owner
    ) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        transferOwnership(_owner);
    }

    function createPoolPosition(
        uint _amount,
        uint _amountToSwap,
        uint _poolId
    ) external nonReentrant {
        require(_amount > 0, "PeanutDCA:: amount must be greater than zero");
        require(_amountToSwap > 0, "PeanutDCA:: amount to swap must be greater than zerp");

        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[pool.inputToken][msg.sender];

        _deposit(_amount, _poolId);

        user.amountToSwap = _amountToSwap;
        pool.totalAmountToSwap = pool.totalAmountToSwap + _amountToSwap;
    }

    function deposit(uint _amount, uint _poolId) external nonReentrant {
        _deposit(_amount, _poolId);
    }

    function withdraw(uint _amount, uint _poolId) external nonReentrant {
        _withdraw(_amount,  _poolId);
    }

    function swap(address[] calldata pools) external onlyOwner nonReentrant {
        for (uint8 i = 0; i < pools.length; i++) {
            PoolInfo memory pool = poolInfo[i];

            IPancakeRouter02(pool.router).swapExactTokensForTokens(
                pool.totalAmountToSwap,
                0, // TODO: consider slippage,
                pool.path, // TODO: find optimal way to pass the route to this function
                address(this),
                block.timestamp
            );
        }
    }

    function createPool(
        address _inputToken,
        address _outputToken,
        address _router,
        address[] memory _path
    ) external onlyOwner nonReentrant {
        poolInfo.push(
            PoolInfo({
                inputToken: _inputToken,
                outputToken: _outputToken,
                router: _router,
                path: _path,
                totalTokensInPool: 0,
                totalAmountToSwap: 0,
                lastSwap: 0
            })
        );
    }

    //INTERNAL FUNCTIONS
    function _deposit(uint _amount, uint _poolId) internal virtual {
        require(_amount > 0, "PeanutDCA:: amount must be greater than zero");

        PoolInfo storage pool = poolInfo[_poolId];

        IERC20Upgradeable(pool.inputToken).safeTransferFrom(msg.sender, address(this), _amount);

        UserInfo storage user = userInfo[pool.inputToken][msg.sender];

        user.stake = user.stake + _amount; // TODO: current - initial balance
        user.lastDepositTime = block.timestamp;

        pool.totalTokensInPool = pool.totalTokensInPool + _amount;

        emit Deposit(msg.sender, pool.inputToken, _amount);
    }

    function _withdraw(uint _amount, uint _poolId) internal {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage userInfo = userInfo[pool.inputToken][msg.sender];

        require(_amount > 0, "PeanutDCA:: withdraw amount must be greater than zero");
        require(_amount <= userInfo.stake, "PeanutDCA:: withdraw amount must less than or equal to token balance");
        require(_amount <= pool.totalTokensInPool, "PeanutDCA:: not enough tokens in the contract");

        IERC20Upgradeable(pool.inputToken).safeTransfer(msg.sender, _amount);

        pool.totalTokensInPool = PeanutHelpers.currentBalance(pool.inputToken);
        userInfo.stake = userInfo.stake - _amount;

        emit Withdraw(msg.sender, pool.inputToken, _amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
