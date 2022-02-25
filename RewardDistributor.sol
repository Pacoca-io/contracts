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
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract RewardDistributor is Initializable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    IERC20 public WBNB;

    address public treasury;
    address public dao;

    uint public KEEPER_FEE;
    uint public DAO_FEE;
    uint public TOTAL_FEE;

    function initialize (
        address _wbnb,
        address _treasury,
        address _dao
    ) public initializer {
        WBNB = IERC20(_wbnb);
        treasury = _treasury;
        dao = _dao;

        KEEPER_FEE = 50;
        DAO_FEE = 500;
        TOTAL_FEE = 550;
    }

    function distribute() external {
        WBNB.transfer(
            dao,
            WBNB.balanceOf(address(this)).mul(DAO_FEE).div(TOTAL_FEE)
        );

        WBNB.transfer(
            treasury,
            WBNB.balanceOf(address(this))
        );
    }
}
