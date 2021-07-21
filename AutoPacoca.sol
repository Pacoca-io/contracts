// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// TODO use interface
import "./PacocaFarm.sol";

contract AutoPacoca is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        bool isPacocaMaximizer; // only pacoca maximizer contracts are allowed to interact with some functions
        uint256 shares; // number of shares for a user
        uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
        uint256 pacocaAtLastUserAction; // keeps track of pacoca deposited at the last user action
    }

    IERC20 public immutable token; // Pacoca token

    PacocaFarm public immutable masterchef;

    mapping(address => UserInfo) public userInfo;

    uint256 public totalShares;
    uint256 public lastHarvestBlock;

    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);
    event Harvest(address indexed sender);
    event PacocaMaximizerAdded(address indexed maximizer);

    /**
     * @notice Constructor
     * @param _token: Pacoca token contract
     * @param _masterchef: MasterChef contract
     * @param _owner: address of the owner
     */
    constructor(
        IERC20 _token,
        PacocaFarm _masterchef,
        address _owner
    ) public {
        token = _token;
        masterchef = _masterchef;
        transferOwnership(_owner);

        // TODO use approve if needed
        // Infinite approve
        IERC20(_token).safeApprove(address(_masterchef), uint256(- 1));
    }

    /**
     * @notice Checks if the msg.sender is a pacoca maximizer contract
     */
    modifier onlyPacocaMaximizer() {
        require(
            userInfo[msg.sender].isPacocaMaximizer,
            "AutoPacoca: only pacoca maximizer is allowed"
        );
        _;
    }

    /**
     * @notice Reinvests PACOCA tokens into MasterChef
     */
    function harvest() external {
        require(
            block.number <= lastHarvestBlock,
            "AutoPacoca: Rewards already harvested"
        );

        PacocaFarm(masterchef).withdraw(0, 0);

        _earn();

        lastHarvestBlock = block.number;

        emit Harvest(msg.sender);
    }

    /**
     * @notice Deposits funds into the Pacoca Vault
     * @param _amount: number of tokens to deposit (in PACOCA)
     */
    function deposit(uint256 _amount) external onlyPacocaMaximizer nonReentrant {
        require(_amount > 0, "Nothing to deposit");

        uint256 pool = underlyingTokenBalance();
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 currentShares = 0;
        if (totalShares != 0) {
            currentShares = (_amount.mul(totalShares)).div(pool);
        } else {
            currentShares = _amount;
        }
        UserInfo storage user = userInfo[msg.sender];

        user.shares = user.shares.add(currentShares);
        user.lastDepositedTime = block.timestamp;

        totalShares = totalShares.add(currentShares);

        user.pacocaAtLastUserAction = user.shares.mul(underlyingTokenBalance()).div(totalShares);

        _earn();

        emit Deposit(msg.sender, _amount, currentShares, block.timestamp);
    }

    /**
     * @notice Withdraws from funds from the Pacoca Vault
     * @param _shares: Number of shares to withdraw
     */
    function withdraw(uint256 _shares) public onlyPacocaMaximizer nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(_shares > 0, "AutoPacoca: Nothing to withdraw");
        require(_shares <= user.shares, "AutoPacoca: Withdraw amount exceeds balance");

        uint256 currentAmount = (underlyingTokenBalance().mul(_shares)).div(totalShares);
        user.shares = user.shares.sub(_shares);
        totalShares = totalShares.sub(_shares);

        uint256 bal = available();
        if (bal < currentAmount) {
            uint256 balWithdraw = currentAmount.sub(bal);
            PacocaFarm(masterchef).withdraw(0, balWithdraw);
            uint256 balAfter = available();
            uint256 diff = balAfter.sub(bal);
            if (diff < balWithdraw) {
                currentAmount = bal.add(diff);
            }
        }

        if (user.shares > 0) {
            user.pacocaAtLastUserAction = user.shares.mul(underlyingTokenBalance()).div(totalShares);
        } else {
            user.pacocaAtLastUserAction = 0;
        }

        token.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount, _shares);
    }

    /**
     * @notice Withdraws all funds for a user
     */
    function withdrawAll() external {
        withdraw(userInfo[msg.sender].shares);
    }

    /**
     * @notice Calculates the total pending rewards that can be restaked
     * @return Returns total pending Pacoca rewards
     */
    function calculateTotalPendingPacocaRewards() external view returns (uint256) {
        uint256 amount = PacocaFarm(masterchef).pendingPACOCA(0, address(this));
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
        (uint256 amount,) = PacocaFarm(masterchef).userInfo(0, address(this));

        return token.balanceOf(address(this)).add(amount);
    }

    // TODO check if this is necessary
    function balanceOf(address _user) external view returns (uint256) {
        return userInfo[_user].shares.mul(getPricePerFullShare()).div(1e18);
    }

    function sharesOf(address _user) external view returns (uint256) {
        return userInfo[_user].shares;
    }

    function addPacocaMaximizer(address _maximizer) external onlyOwner {
        userInfo[_maximizer].isPacocaMaximizer = true;

        emit PacocaMaximizerAdded(_maximizer);
    }

    /**
     * @notice Deposits tokens into MasterChef to earn staking rewards
     */
    function _earn() internal {
        uint256 bal = available();

        if (bal > 0) {
            PacocaFarm(masterchef).deposit(0, bal);
        }
    }
}
