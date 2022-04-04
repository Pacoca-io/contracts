// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";

interface IwNative is IERC20 {
    function deposit() external payable;

    function withdraw(uint) external;
}
