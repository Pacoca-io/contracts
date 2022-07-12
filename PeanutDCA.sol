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
import "@openzeppelin/contracts-upgradeable-v4/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract PeanutDCA is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct PoolInfo {
        address inputToken;
        uint totalTokensInPool;
        uint amountToSwap;
        uint lastSwap;
    }

    struct UserInfo {
        uint stake;
        uint amountToSwap;
        uint rewardDebt;
        uint lastDepositTime;
    }

    // token address => user address => user info
    mapping(address => mapping(address => UserInfo)) public userInfo;
    mapping(address => PoolInfo) public poolInfo;

    event Deposit(address indexed user, address indexed token, uint amount);
    event CreateStrategy(uint stake, uint amout, address indexed token);

    function initialize(
        address _owner
    ) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(_owner);
    }

    function createStrategy(uint _amount, uint _amountToSwap, address _token) public {
        UserInfo storage user = userInfo[_token][msg.sender];

        _deposit(_amount, _token);

        user.amountToSwap = _amountToSwap;
    }

    function deposit(uint _amount, address _token) public nonReentrant {
        _deposit(_amount, _token);
    }

    function _deposit(uint _amount,  address _token) internal virtual {
        require(_amount > 0, "PeanutDCA:: amount must be greater than zero");

        IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);

        UserInfo storage user = userInfo[_token][msg.sender];
        PoolInfo storage pool = poolInfo[address(_token)];

        user.stake = user.stake + _amount;
        user.lastDepositTime = block.timestamp;

        pool.totalTokensInPool = pool.totalTokensInPool + _amount;

        emit Deposit(msg.sender, _token, _amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
