// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAutoPacoca {
    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _shares) external;

    function getPricePerFullShare() external view returns (uint256);

    function sharesOf(address _user) external view returns (uint256);
}
