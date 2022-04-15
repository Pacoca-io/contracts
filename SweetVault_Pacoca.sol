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

contract SweetVault_Pacoca is SweetVault_v1 {
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

    function earn(
        uint256 _minPlatformOutput,
        uint256 _minKeeperOutput,
        uint256,
        uint256
    ) external override onlyKeeper {
        STAKED_TOKEN_FARM.withdraw(FARM_PID, 0);

        uint256 rewardTokenBalance = _rewardTokenBalance();

        // Collect platform fees
        if (platformFee > 0) {
            _swap(
                rewardTokenBalance.mul(platformFee).div(10000),
                _minPlatformOutput,
                pathToWbnb,
                platform
            );
        }

        // Collect keeper fees
        if (keeperFee > 0) {
            _swap(
                rewardTokenBalance.mul(keeperFee).div(10000),
                _minKeeperOutput,
                pathToWbnb,
                treasury
            );
        }

        // Collect Burn fees
        if (buyBackRate > 0) {
            _safePACOCATransfer(
                BURN_ADDRESS,
                rewardTokenBalance.mul(buyBackRate).div(10000)
            );
        }

        uint256 previousShares = totalAutoPacocaShares();
        uint256 pacocaBalance = _rewardTokenBalance();

        _approveTokenIfNeeded(
            PACOCA,
            pacocaBalance,
            address(AUTO_PACOCA)
        );

        AUTO_PACOCA.deposit(pacocaBalance);

        uint256 currentShares = totalAutoPacocaShares();

        accSharesPerStakedToken = accSharesPerStakedToken.add(
            currentShares.sub(previousShares).mul(1e18).div(totalStake())
        );
    }

    function _getExpectedOutput(
        address[] memory _path
    ) internal view override returns (uint256) {
        uint256 pending = STAKED_TOKEN_FARM.pendingPACOCA(FARM_PID, address(this));

        uint256 rewards = _rewardTokenBalance().add(pending);

        uint256[] memory amounts = router.getAmountsOut(rewards, _path);

        return amounts[amounts.length.sub(1)];
    }
}
