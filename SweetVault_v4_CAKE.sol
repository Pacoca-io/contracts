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

import "./SweetVault_v4.sol";
import "./interfaces/ICakePool.sol";

contract SweetVault_v4_CAKE is SweetVault_v4 {
    address constant public CAKE_POOL = 0x45c54210128a065de780C4B0Df3d16664f7f859e;
    address constant public CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    uint internal _totalStake;

    function harvest() internal override {
        ICakePool(CAKE_POOL).withdraw(profitInShares());
    }

    function _deposit(uint _amount) internal override {
        UserInfo storage user = userInfo[msg.sender];
        ICakePool cakePool = ICakePool(CAKE_POOL);

        _approveTokenIfNeeded(
            farmInfo.stakedToken,
            _amount,
            CAKE_POOL
        );

        (uint initialShares, , , , , , , ,) = cakePool.userInfo(address(this));

        cakePool.deposit(_amount, 0);

        // TODO if this fails use shares as stake instead of token amount
        (uint currentShares, , , , , , , ,) = cakePool.userInfo(address(this));

        uint depositValue = _sharesValue(currentShares - initialShares);

        _totalStake = _totalStake + depositValue;

        _updateAutoPacocaShares(user);
        user.stake = user.stake + depositValue;
        _updateRewardDebt(user);
        user.lastDepositedTime = block.timestamp;

        emit Deposit(msg.sender, depositValue);
    }

    function _withdrawUnderlying(uint _amount) internal override returns (uint) {
        ICakePool(CAKE_POOL).withdrawByAmount(_amount);

        uint balance = IERC20Upgradeable(CAKE).balanceOf(address(this));

        _totalStake = _totalStake - balance;

        return balance;
    }

    function _getExpectedOutput(
        address[] memory _path
    ) internal virtual view override returns (uint) {
        uint rewards = _currentBalance(CAKE) + profit();

        if (rewards == 0) {
            return 0;
        }

        uint[] memory amounts = router.getAmountsOut(rewards, _path);

        return amounts[amounts.length - 1];
    }

    function profit() public view returns (uint) {
        ICakePool cakePool = ICakePool(CAKE_POOL);

        (uint shares, , , , , , , ,) = cakePool.userInfo(address(this));

        return _sharesValue(shares) - _totalStake;
    }

    function profitInShares() public view returns (uint) {
        return profit() * 1e18 / ICakePool(CAKE_POOL).getPricePerFullShare();
    }

    function totalStake() public view override returns (uint) {
        return _totalStake;
    }

    function _sharesValue(uint shares) internal view returns (uint) {
        return shares * ICakePool(CAKE_POOL).getPricePerFullShare() / 1e18;
    }
}
