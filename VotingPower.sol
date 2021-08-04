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

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPancakePair.sol";

interface IToken {
    function balanceOf(address _user) external view returns (uint256);
}

interface IFarm {
    function stakedWantTokens(
        uint256 _pid,
        address _user
    ) external view returns (uint256);

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 _pid) external view returns (address want);
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

contract VotingPower is Ownable {
    using SafeMath for uint256;

    IToken public PACOCA = IToken(0x55671114d774ee99D653D6C12460c780a67f1D18);
    IFarm public PACOCA_FARM = IFarm(0x55410D946DFab292196462ca9BE9f3E4E4F337Dd);
    IVault public PACOCA_VAULT = IVault(0x16205528A8F7510f4421009a7654835b541bb1b9);

    mapping(uint256 => bool) public pacocaPairs;

    event PacocaPairAdded(uint256 _pid);
    event PacocaPairRemoved(uint256 _pid);

    constructor(address _owner) public {
        addPacocaPairPid(2);
        addPacocaPairPid(15);
        addPacocaPairPid(16);
        addPacocaPairPid(21);
        addPacocaPairPid(22);

        transferOwnership(_owner);
    }

    function votingPower(address _user) external view returns (uint256) {
        uint256 tokenBalance = PACOCA.balanceOf(_user);
        uint256 farmBalance = PACOCA_FARM.stakedWantTokens(0, _user);
        uint256 pairBalance = _getPacocaPairBalances(_user);
        uint256 vaultBalance = _getPacocaVaultBalance(_user);

        return tokenBalance.add(farmBalance).add(pairBalance).add(vaultBalance);
    }

    function _getPacocaVaultBalance(address _user) private view returns (uint256){
        uint256 pricePerShare = PACOCA_VAULT.getPricePerFullShare();
        (uint256 shares, , ,) = PACOCA_VAULT.userInfo(_user);

        return shares.mul(pricePerShare).div(1e18);
    }

    function _getPacocaPairBalances(address _user) private view returns (uint256 balance) {
        uint256 length = PACOCA_FARM.poolLength();

        for (uint256 pid = 0; pid < length; ++pid) {
            if (!pacocaPairs[pid]) {
                continue;
            }

            uint256 pairBalance = PACOCA_FARM.stakedWantTokens(pid, _user);

            if (pairBalance > 0) {
                balance = balance.add(
                    _getPacocaPairBalance(PACOCA_FARM.poolInfo(pid), pairBalance)
                );
            }
        }

        return balance;
    }

    function _getPacocaPairBalance(address _pair, uint256 _balance) private view returns (uint256) {
        IPancakePair pair = IPancakePair(_pair);

        bool pacocaToken0 = pair.token0() == address(PACOCA);
        bool pacocaToken1 = pair.token1() == address(PACOCA);

        if (!pacocaToken0 && !pacocaToken1) {
            return 0;
        }

        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

        return pacocaToken0
        ? reserve0.mul(_balance).div(pair.totalSupply())
        : reserve1.mul(_balance).div(pair.totalSupply());
    }

    function addPacocaPairPid(uint256 _pid) public onlyOwner {
        pacocaPairs[_pid] = true;

        emit PacocaPairAdded(_pid);
    }

    function removePacocaPairPid(uint256 _pid) public onlyOwner {
        pacocaPairs[_pid] = false;

        emit PacocaPairRemoved(_pid);
    }
}
