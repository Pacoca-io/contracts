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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IPancakeswapFarm.sol";
import "./interfaces/IPancakeRouter01.sol";
// TODO Add autopacoca interface
import "./AutoPacoca.sol";

contract PacocaMaximizer is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        // How many assets the user has provided.
        uint256 stake;
        // How many staked $PACOCA user had at his last action
        uint256 pacocaShares;
        // Pacoca shares not entitled to the user
        uint256 rewardDebt;
    }

    // Addresses
    address constant public BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address constant public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IERC20 constant public PACOCA = IERC20(0x55671114d774ee99D653D6C12460c780a67f1D18);
    AutoPacoca constant public AUTO_PACOCA = AutoPacoca(0x55410D946DFab292196462ca9BE9f3E4E4F337Dd);
    IERC20 immutable public STAKED_TOKEN;

    // Runtime data
    mapping(address => UserInfo) public userInfo; // Info of users
    //    uint256 public totalStake; // Amount of staked tokens
    uint256 public accSharesPerStakedToken; // Accumulated AUTO_PACOCA shares per staked token, times 1e12.
    uint256 public lastHarvestBlock;

    // Farm info
    IPancakeswapFarm immutable public STAKED_TOKEN_FARM;
    IERC20 immutable public REWARD_TOKEN;
    uint256 immutable public FARM_PID;
    bool immutable IS_CAKE_STAKING;

    // Settings
    IPancakeRouter01 public router;
    address[] public path; // Path from staked token to PACOCA
    uint256 public buyBackRate = 200; // 2%
    uint256 public constant buyBackRateUL = 800; // 8%
    uint256 public slippageFactor = 950; // 5% default slippage tolerance

    //    uint256 public constant slippageFactorUL = 995;

    event Deposit(address indexed user, uint256 amount);

    constructor(
        address _stakedToken,
        address _stakedTokenFarm,
        address _rewardToken,
        uint256 _farmPid,
        bool _isCakeStaking,
        address _router,
        address[] memory _path
    ) public {
        STAKED_TOKEN = IERC20(_stakedToken);
        STAKED_TOKEN_FARM = IPancakeswapFarm(_stakedTokenFarm);
        REWARD_TOKEN = IERC20(_rewardToken);
        FARM_PID = _farmPid;
        IS_CAKE_STAKING = _isCakeStaking;

        router = IPancakeRouter01(_router);
        path = _path;
    }

    // 1. Harvest rewards
    // 2. Convert rewards to $PACOCA
    // 3. Harvest pacoca pool rewards
    // 4. Collect fees
    // 5. Stake to pacoca pool
    // TODO onlyBot
    function earn(uint256 _minPacocaOutput) external {
        require(
            block.number <= lastHarvestBlock,
            "PacocaMaximizer: Sorry, you're late"
        );

        // Claim rewards
        if (IS_CAKE_STAKING) {
            STAKED_TOKEN_FARM.leaveStaking(0);
        } else {
            STAKED_TOKEN_FARM.withdraw(FARM_PID, 0);
        }

        _convertBalanceToPacoca(_minPacocaOutput);

        _safePACOCATransfer(
            BURN_ADDRESS,
            _pacocaBalance().mul(buyBackRate).div(10000)
        );

        uint256 previousShares = AUTO_PACOCA.sharesOf(address(this));

        AUTO_PACOCA.deposit(_pacocaBalance());

        uint256 currentShares = AUTO_PACOCA.sharesOf(address(this));

        accSharesPerStakedToken = accSharesPerStakedToken.add(
            currentShares.sub(previousShares).mul(1e12).div(_totalStake())
        );

        lastHarvestBlock = block.number;
    }

    //    function pendingPACOCA(address _user) external view returns (uint256) {
    //        UserInfo storage user = userInfo[_user];
    //
    //        return user.stake.mul(rewardsPerStake).div(1e12).sub(user.rewardDebt);
    //    }

    // Deposit cake to pancake's masterchef
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "PacocaMaximizer: amount must be greater than zero");

        UserInfo storage user = userInfo[msg.sender];

        STAKED_TOKEN.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        _approveTokenIfNeeded(
            STAKED_TOKEN,
            _amount,
            address(STAKED_TOKEN_FARM)
        );

        if (IS_CAKE_STAKING) {
            // For CAKE staking, we dont use deposit()
            STAKED_TOKEN_FARM.enterStaking(_amount);
        } else {
            STAKED_TOKEN_FARM.deposit(FARM_PID, _amount);
        }

        // totalStake = totalStake.add(_amount);

        // TODO check if rewardDebt is correct
        user.pacocaShares = user.pacocaShares.add(
            user.pacocaShares.mul(accSharesPerStakedToken).div(1e12).sub(
                user.rewardDebt
            )
        );
        user.stake = user.stake.add(_amount);
        user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e12);

        emit Deposit(msg.sender, _amount);
    }

    function getExpectedPacocaOutput() external view returns (uint256) {
        uint256 rewards = _rewardTokenBalance().add(_totalStake());

        uint256[] memory amounts = router.getAmountsOut(rewards, path);

        return amounts[amounts.length.sub(1)];
    }

    // TODO add update path, router, buyback, slippageFactor function

    function _approveTokenIfNeeded(
        IERC20 _token,
        uint256 _amount,
        address _spender
    ) private {
        if (_token.allowance(address(this), _spender) < _amount) {
            _token.safeApprove(_spender, uint(- 1));
        }
    }

    function _rewardTokenBalance() private view returns (uint256) {
        return REWARD_TOKEN.balanceOf(address(this));
    }

    function _pacocaBalance() private view returns (uint256) {
        return PACOCA.balanceOf(address(this));
    }

    function _totalStake() private view returns (uint256) {
        return STAKED_TOKEN_FARM.pendingCake(FARM_PID, address(this));
    }

    // Safe PACOCA transfer function, just in case if rounding error causes pool to not have enough
    function _safePACOCATransfer(address _to, uint256 _amount) private {
        uint256 balance = _pacocaBalance();

        if (_amount > balance) {
            PACOCA.transfer(_to, balance);
        } else {
            PACOCA.transfer(_to, _amount);
        }
    }

    function _convertBalanceToPacoca(uint256 _minPacocaOutput) private {
        uint256 rewardTokenBalance = _rewardTokenBalance();

        _approveTokenIfNeeded(
            REWARD_TOKEN,
            rewardTokenBalance,
            address(router)
        );

        router.swapExactTokensForTokens(
            rewardTokenBalance, // input amount
            _minPacocaOutput,
            path, // path
            address(this), // to
            block.timestamp // deadline
        );
    }
}
