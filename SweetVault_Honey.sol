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

pragma solidity 0.6.12;

import "./SweetVault_v1.sol";

contract SweetVault_Honey is SweetVault_v1 {
    constructor(
        address _autoPacoca,
        address _stakedToken,
        address _stakedTokenFarm,
        address _farmRewardToken,
        uint256 _farmPid,
        bool _isCakeStaking,
        address _router,
        address[] memory _pathToPacoca,
        address[] memory _pathToWbnb,
        address _owner,
        address _treasury,
        address _keeper,
        address _platform,
        uint256 _buyBackRate,
        uint256 _platformFee
    ) SweetVault_v1(
        _autoPacoca,
        _stakedToken,
        _stakedTokenFarm,
        _farmRewardToken,
        _farmPid,
        _isCakeStaking,
        _router,
        _pathToPacoca,
        _pathToWbnb,
        _owner,
        _treasury,
        _keeper,
        _platform,
        _buyBackRate,
        _platformFee
    ) public {}

    function deposit(uint256 _amount) external override nonReentrant {
        require(_amount > 0, "SweetVault: amount must be greater than zero");

        UserInfo storage user = userInfo[msg.sender];

        uint256 initialBalance = _stakedTokenBalance();
        uint256 initialStake = totalStake();

        STAKED_TOKEN.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        uint256 amountReceived = _stakedTokenBalance().sub(initialBalance);

        _approveTokenIfNeeded(
            STAKED_TOKEN,
            amountReceived,
            address(STAKED_TOKEN_FARM)
        );

        STAKED_TOKEN_FARM.deposit(FARM_PID, amountReceived, treasury);

        user.autoPacocaShares = user.autoPacocaShares.add(
            user.stake.mul(accSharesPerStakedToken).div(1e18).sub(
                user.rewardDebt
            )
        );
        user.stake = user.stake.add(totalStake().sub(initialStake));
        user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);
        user.lastDepositedTime = block.timestamp;

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external override nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(_amount > 0, "SweetVault: amount must be greater than zero");
        require(user.stake >= _amount, "SweetVault: withdraw amount exceeds balance");

        uint256 initialBalance = _stakedTokenBalance();

        STAKED_TOKEN_FARM.withdraw(FARM_PID, _amount);

        uint256 currentAmount = _stakedTokenBalance().sub(initialBalance);

        if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
            uint256 currentWithdrawFee = currentAmount.mul(earlyWithdrawFee).div(10000);

            STAKED_TOKEN.safeTransfer(treasury, currentWithdrawFee);

            currentAmount = currentAmount.sub(currentWithdrawFee);

            emit EarlyWithdraw(msg.sender, _amount, currentWithdrawFee);
        }

        user.autoPacocaShares = user.autoPacocaShares.add(
            user.stake.mul(accSharesPerStakedToken).div(1e18).sub(
                user.rewardDebt
            )
        );
        user.stake = user.stake.sub(_amount);
        user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);

        // Withdraw pacoca rewards if user leaves
        if (user.stake == 0 && user.autoPacocaShares > 0) {
            _claimRewards(user.autoPacocaShares, false);
        }

        STAKED_TOKEN.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount);
    }

    function _getExpectedOutput(
        address[] memory _path
    ) internal view override returns (uint256) {
        uint256 pending = STAKED_TOKEN_FARM.pendingEarnings(FARM_PID, address(this));

        uint256 rewards = _rewardTokenBalance().add(pending);

        uint256[] memory amounts = router.getAmountsOut(rewards, _path);

        return amounts[amounts.length.sub(1)];
    }

    function _stakedTokenBalance() private view returns (uint256) {
        return STAKED_TOKEN.balanceOf(address(this));
    }

    function _swap(
        uint256 _inputAmount,
        uint256 _minOutputAmount,
        address[] memory _path,
        address _to
    ) internal override {
        _approveTokenIfNeeded(
            FARM_REWARD_TOKEN,
            _inputAmount,
            address(router)
        );

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _inputAmount,
            _minOutputAmount,
            _path,
            _to,
            block.timestamp
        );
    }
}
