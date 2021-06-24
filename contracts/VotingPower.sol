// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

interface IToken {
    function balanceOf(address _user) external view returns (uint256);
}

interface IFarm {
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);
}

interface IVault {
    function userInfo(
        address _user
    ) external view returns (
        uint256 shares,
        uint256 lastDepositedTime,
        uint256 pacocaAtLastUserAction,
        uint256 lastUserActionTime
    );

    function getPricePerFullShare() external view returns (uint256);
}

contract VotingPower {
    using SafeMath for uint256;

    IToken public PACOCA = IToken(0x55671114d774ee99D653D6C12460c780a67f1D18);
    IFarm public PACOCA_FARM = IFarm(0x55410D946DFab292196462ca9BE9f3E4E4F337Dd);
    IVault public PACOCA_VAULT = IVault(0x16205528A8F7510f4421009a7654835b541bb1b9);

    function votingPower(address _user) external view returns (uint256) {
        uint256 tokenBalance = PACOCA.balanceOf(_user);
        uint256 farmBalance = PACOCA_FARM.stakedWantTokens(0, _user);
        uint256 vaultPricePerShare = PACOCA_VAULT.getPricePerFullShare();
        (uint256 vaultShares, , ,) = PACOCA_VAULT.userInfo(_user);
        uint256 vaultBalance = vaultShares.mul(vaultPricePerShare).div(1e18);

        return tokenBalance.add(farmBalance).add(vaultBalance);
    }
}
