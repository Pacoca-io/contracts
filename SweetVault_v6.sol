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

import "./SweetVault_v5.sol";

contract SweetVault_v6 is SweetVault_v5 {
    function withdrawAndUnZap(
        UnZapInfo memory _unZapInfo,
        address _outputToken
    ) external payable nonReentrant {

        UserInfo storage user = userInfo[msg.sender];
        address stakedToken = farmInfo.stakedToken;
        bool isOutputNative = _outputToken == address(0);

        require(_unZapInfo.inputTokenAmount > 0, "SweetVault: amount must be greater than zero");
        require(user.stake >= _unZapInfo.inputTokenAmount, "SweetVault: withdraw amount exceeds balance");

        (uint withdrawFee, uint withdrawAmount) = _getWithdrawInfo(
            user.lastDepositedTime,
            _unZapInfo.inputTokenAmount
        );
        uint currentAmount = _withdrawUnderlying(_unZapInfo.inputTokenAmount);

        if (withdrawFee > 0) {
            // TODO: safe transfer
            IERC20Upgradeable(stakedToken).transfer(authority.treasury(), withdrawFee);

            _unZapInfo.inputTokenAmount = withdrawAmount;

            emit EarlyWithdraw(msg.sender, withdrawAmount, withdrawFee);
        }

        _updateAutoPacocaShares(user);
        user.stake = user.stake - withdrawAmount;
        _updateRewardDebt(user);

        IERC20Upgradeable(_unZapInfo.inputToken).approve(zap, withdrawAmount);

        if (isOutputNative) {
            uint initialOutputTokenBalance = address(this).balance;

            IPeanutZap(zap).unZapNative(_unZapInfo);

            payable(msg.sender).transfer(address(this).balance - initialOutputTokenBalance);
        } else {
            uint initialOutputTokenBalance = _currentBalance(_outputToken);

            IPeanutZap(zap).unZapToken(_unZapInfo, _outputToken);

            IERC20Upgradeable(_outputToken).transfer(msg.sender, _currentBalance(_outputToken) - initialOutputTokenBalance);
        }
    }

    function _getWithdrawInfo(
        uint _lastDepositedTime,
        uint _amount
    ) public view returns (uint withdrawFee, uint withdrawAmount) {
        withdrawFee = block.timestamp < _lastDepositedTime + withdrawFeePeriod
            ? (_amount * earlyWithdrawFee) / 10000
            : 0;

        withdrawAmount = _amount - withdrawFee;
    }
}
