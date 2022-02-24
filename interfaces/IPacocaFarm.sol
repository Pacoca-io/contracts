// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12 <=0.8.12;

interface IPacocaFarm {
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    function deposit(uint256 _pid, uint256 _wantAmt) external;

    function withdraw(uint256 _pid, uint256 _wantAmt) external;

    function userInfo(uint256 _pid, address _user) external view returns (uint256 shares, uint256 rewardDebt);

    function pendingPACOCA(uint256 _pid, address _user) external view returns (uint256);

    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);
}
