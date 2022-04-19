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

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable-v4/proxy/utils/Initializable.sol";
import "./IAuthorityUpgraded.sol";

abstract contract AccessControlledUpgraded is Initializable {
    event AuthorityUpdated(address indexed authority);

    IAuthorityUpgraded public authority;

    function __AccessControlled_init(address _authority) public initializer {
        authority = IAuthorityUpgraded(_authority);

        emit AuthorityUpdated(_authority);
    }

    modifier requireRole(IAuthorityUpgraded.Role _role) {
        require(
            authority.userRoles(_role, msg.sender),
            "Authority::requireRole: Unauthorized"
        );

        _;
    }

    function setAuthority(address _newAuthority) external virtual requireRole(IAuthorityUpgraded.Role.DAO) {
        authority = IAuthorityUpgraded(_newAuthority);

        emit AuthorityUpdated(_newAuthority);
    }
}
