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

import "@openzeppelin/contracts-upgradeable-v4/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable-v4/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable-v4/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IPacocaFarm.sol";

contract WrappedPacoca is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 constant public PACOCA = IERC20(0x55671114d774ee99D653D6C12460c780a67f1D18);
    IPacocaFarm constant public PACOCA_FARM = IPacocaFarm(0x55410D946DFab292196462ca9BE9f3E4E4F337Dd);
    uint constant public POOL_ID = 0;

    function initialize(address _owner) public initializer {
        PACOCA.safeApprove(address(PACOCA_FARM), (2 ** 256) - 1);

        __ERC20_init("Wrapped Pacoca", "wPACOCA");
        __ReentrancyGuard_init();
        __Ownable_init();

        transferOwnership(_owner);
    }

    // it calculate the total underlying pacoca this contract holds.
    function balance() public view returns (uint) {
        return pacocaBalance() + stakedBalance();
    }

    // it calculates how much pacoca this contract holds.
    function pacocaBalance() public view returns (uint) {
        return PACOCA.balanceOf(address(this));
    }

    // it calculates how much pacoca this contract has working in the farm.
    function stakedBalance() public view returns (uint) {
        return PACOCA_FARM.stakedWantTokens(POOL_ID, address(this));
    }

    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an uint with 18 decimals of how much underlying asset one vault share represents.
     */
    function getPricePerFullShare() public view returns (uint) {
        return totalSupply() == 0 ? 1e18 : (balance() * 1e18) / totalSupply();
    }

    /**
     * @dev A helper function to call deposit() with all the sender's funds.
     */
    function depositAll() external {
        deposit(PACOCA.balanceOf(msg.sender));
    }

    /**
     * @dev The entrypoint of funds into the system. People deposit with this function
     * into the vault. The vault is then in charge of sending funds into the strategy.
     */
    function deposit(uint _amount) public nonReentrant {
        // Collect pending rewards
        PACOCA_FARM.deposit(POOL_ID, 0);

        uint initialBalance = balance();

        PACOCA.safeTransferFrom(msg.sender, address(this), _amount);

        earn();

        _amount = balance() - initialBalance;

        uint shares = 0;

        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / initialBalance;
        }

        _mint(msg.sender, shares);
    }

    /**
     * @dev Function to send funds into the strategy and put them to work. It's primarily called
     * by the vault's deposit() function.
     */
    function earn() public {
        uint contractBalance = pacocaBalance();

        if (contractBalance > 0)
            PACOCA_FARM.deposit(POOL_ID, contractBalance);
    }

    /**
     * @dev A helper function to call withdraw() with all the sender's funds.
     */
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /**
     * @dev Function to exit the system. The vault will withdraw the required tokens
     * from the farm and pay up the token holder.
     * A proportional number of IOU tokens are burned in the process.
     */
    function withdraw(uint _shares) public nonReentrant {
        uint requestedAmount = (balance() * _shares) / totalSupply();

        _burn(msg.sender, _shares);

        uint initialBalance = pacocaBalance();

        if (initialBalance < requestedAmount) {
            uint withdrawAmount = requestedAmount - initialBalance;

            PACOCA_FARM.withdraw(POOL_ID, withdrawAmount);
        }

        PACOCA.safeTransfer(msg.sender, requestedAmount);
    }

    /**
     * @dev Rescues random funds stuck that the strat can't handle.
     * @param _token address of the token to rescue.
     */
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(PACOCA), "wPACOCA::inCaseTokensGetStuck: token not allowed");

        uint amount = IERC20(_token).balanceOf(address(this));

        IERC20(_token).safeTransfer(msg.sender, amount);
    }
}
