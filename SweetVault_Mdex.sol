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

import "./SweetVault.sol";

contract SweetVault_Mdex is SweetVault {
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
    ) SweetVault(
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

    function _getExpectedOutput(
        address[] memory _path
    ) internal view override returns (uint256) {
        uint256 pending = STAKED_TOKEN_FARM.pending(FARM_PID, address(this));

        uint256 rewards = _rewardTokenBalance().add(pending);

        uint256[] memory amounts = router.getAmountsOut(rewards, _path);

        return amounts[amounts.length.sub(1)];
    }
}
