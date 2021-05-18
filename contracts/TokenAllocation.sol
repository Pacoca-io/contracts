// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Pacoca.sol";

import "hardhat/console.sol";

contract TokenAllocation is Ownable {
    using SafeMath for uint256;

    Pacoca pacoca;

    struct Allocation {
        uint total;
        uint used;
    }

    /*
        Allocation indexes

        0 - Partner farms
        1 - Development fund
        2 - ICO
        3 - Airdrops
        4 - Marketing and Partnerships
        5 - Initial liquidity
    */
    mapping(uint8 => Allocation) public allocations;

    constructor (Pacoca _pacoca) public {
        pacoca = _pacoca;

        allocations[0].total = pacoca.maxSupply().mul(20).div(100);
        allocations[1].total = pacoca.maxSupply().mul(15).div(100);
        allocations[2].total = pacoca.maxSupply().mul(10).div(100);
        allocations[3].total = pacoca.maxSupply().mul(8).div(100);
        allocations[4].total = pacoca.maxSupply().mul(5).div(100);
        allocations[5].total = pacoca.maxSupply().mul(2).div(100);
    }

    /*
        Returns the percentage of minted tokens by the masterchef contract

        - 10000 is equal to 100%
        - 7555 is equal to 75.55%
    */
    function percentageMintedByChef() public view returns (uint256) {
        uint256 mintableByChef = 40000000e18;
        uint256 minted = pacoca.totalSupply() - 60000000e18;

        return minted.mul(10000).div(mintableByChef);
    }

    // ---------- Dev funds ----------

    function claimableDevFunds() public view returns (uint256) {
        Allocation memory allocation = allocations[1];

        return allocation.total.mul(percentageMintedByChef()).div(10000).sub(allocation.used);
    }

    function claimDevFunds() public onlyOwner {
        uint256 amount = claimableDevFunds();

        allocations[1].used += amount;
        pacoca.transfer(msg.sender, amount);
    }

    // ---------- Marketing funds ----------

    function claimableMarketingFunds() public view returns (uint256) {
        Allocation memory allocation = allocations[4];

        return allocation.total.mul(percentageMintedByChef()).div(10000).sub(allocation.used);
    }

    function claimMarketingFunds() public onlyOwner {
        uint256 amount = claimableMarketingFunds();

        allocations[4].used += amount;
        pacoca.transfer(msg.sender, amount);
    }
}
