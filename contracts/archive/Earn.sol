// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IVault {
    function earn() external;
}

contract Earn {
    function earn(address[] calldata _vaults) public {
        uint256 length = _vaults.length;

        for (uint256 index = 0; index < length; ++index) {
            IVault(_vaults[index]).earn();
        }
    }
}
