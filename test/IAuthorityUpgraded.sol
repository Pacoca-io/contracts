pragma solidity 0.8.9;

import "../interfaces/IAuthority.sol";

interface IAuthorityUpgraded {
    // TODO check if possible to upgrade and add new roles
    enum Role {
        DAO,
        OWNER,
        TREASURY,
        KEEPER,
        MANAGER,
        REWARD_DISTRIBUTOR,
        TEST_ROLE // New role to test if we can update enum
    }

    event SetRole(Role indexed role, address indexed user, bool active);

    function dao() external view returns (address);

    function treasury() external view returns (address);

    function rewardDistributor() external view returns (address);

    function userRoles(Role, address) external view returns (bool);
}
