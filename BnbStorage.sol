// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract BnbStorage {
    using SafeERC20 for IERC20;

    IERC20 public immutable WBNB;
    address public immutable VAULT;

    constructor (address _wbnb, address _vault) public {
        WBNB = IERC20(_wbnb);
        VAULT = _vault;
    }

    function collect() external {
        require(
            msg.sender == VAULT,
            "BnbStorage::collect: Only bnb vault is allowed to claim"
        );

        WBNB.safeTransfer(VAULT, balance());
    }

    function balance() public view returns (uint) {
        return WBNB.balanceOf(address(this));
    }
}
