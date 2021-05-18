// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract Pacoca is ERC20("pacoca.io", "PACOCA"), Ownable {
    uint256 public maxSupply = 100000000e18;

    function _toBeMinted() private view returns (uint256) {
        return maxSupply.sub(totalSupply());
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (uint256) {
        uint256 toBeMinted = _toBeMinted();
        uint256 amount = _amount <= toBeMinted ? _amount : toBeMinted;

        _mint(_to, amount);

        console.log("sushi %s, original %s", amount, _amount);

        return amount;
    }
}
