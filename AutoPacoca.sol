// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IPacocaFarm.sol";

contract AutoPacoca is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public immutable token; // Pacoca token

    IPacocaFarm public immutable masterchef;

    mapping(address => uint256) public sharesOf;

    uint256 public totalShares;

    event Deposit(address indexed sender, uint256 amount, uint256 shares);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);
    event Harvest(address indexed sender);

    /**
     * @notice Constructor
     * @param _token: Pacoca token contract
     * @param _masterchef: MasterChef contract
     * @param _owner: address of the owner
     */
    constructor(
        IERC20 _token,
        IPacocaFarm _masterchef,
        address _owner
    ) public {
        token = _token;
        masterchef = _masterchef;

        transferOwnership(_owner);
    }

    /**
     * @notice Reinvests PACOCA tokens into MasterChef
     */
    function harvest() external {
        masterchef.withdraw(0, 0);

        _earn();

        emit Harvest(msg.sender);
    }

    /**
     * @notice Deposits funds into the Pacoca Vault
     * @param _amount: number of tokens to deposit (in PACOCA)
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Nothing to deposit");

        uint256 pool = underlyingTokenBalance();
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 currentShares = 0;

        if (totalShares != 0) {
            currentShares = (_amount.mul(totalShares)).div(pool);
        } else {
            currentShares = _amount;
        }

        sharesOf[msg.sender] = sharesOf[msg.sender].add(currentShares);

        totalShares = totalShares.add(currentShares);

        _earn();

        emit Deposit(msg.sender, _amount, currentShares);
    }

    /**
     * @notice Withdraws from funds from the Pacoca Vault
     * @param _shares: Number of shares to withdraw
     */
    function withdraw(uint256 _shares) public nonReentrant {
        uint256 userShares = sharesOf[msg.sender];

        require(_shares > 0, "AutoPacoca: Nothing to withdraw");
        require(_shares <= userShares, "AutoPacoca: Withdraw amount exceeds balance");

        uint256 currentAmount = (underlyingTokenBalance().mul(_shares)).div(totalShares);
        sharesOf[msg.sender] = userShares.sub(_shares);
        totalShares = totalShares.sub(_shares);

        uint256 bal = available();
        if (bal < currentAmount) {
            uint256 balWithdraw = currentAmount.sub(bal);
            masterchef.withdraw(0, balWithdraw);
            uint256 balAfter = available();
            uint256 diff = balAfter.sub(bal);
            if (diff < balWithdraw) {
                currentAmount = bal.add(diff);
            }
        }

        token.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount, _shares);
    }

    /**
     * @notice Withdraws all funds for a user
     */
    function withdrawAll() external {
        withdraw(sharesOf[msg.sender]);
    }

    /**
     * @notice Calculates the total pending rewards that can be restaked
     * @return Returns total pending Pacoca rewards
     */
    function calculateTotalPendingPacocaRewards() external view returns (uint256) {
        uint256 amount = masterchef.pendingPACOCA(0, address(this));
        amount = amount.add(available());

        return amount;
    }

    /**
     * @notice Calculates the price per share
     */
    function getPricePerFullShare() public view returns (uint256) {
        return totalShares == 0 ? 1e18 : underlyingTokenBalance().mul(1e18).div(totalShares);
    }

    /**
     * @notice Custom logic for how much the vault allows to be borrowed
     * @dev The contract puts 100% of the tokens to work.
     */
    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Calculates the total underlying tokens
     * @dev It includes tokens held by the contract and held in MasterChef
     */
    function underlyingTokenBalance() public view returns (uint256) {
        (uint256 amount,) = masterchef.userInfo(0, address(this));

        return token.balanceOf(address(this)).add(amount);
    }

    /**
     * @notice Deposits tokens into MasterChef to earn staking rewards
     */
    function _earn() internal {
        uint256 balance = available();

        if (balance > 0) {
            if (token.allowance(address(this), address(masterchef)) < balance) {
                token.safeApprove(address(masterchef), uint(- 1));
            }

            masterchef.deposit(0, balance);
        }
    }
}
