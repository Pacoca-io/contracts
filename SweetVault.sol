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
import "./interfaces/IPacocaVault.sol";

contract SweetVault is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        // How many assets the user has provided.
        uint256 stake;
        // How many staked $PACOCA user had at his last action
        uint256 autoPacocaShares;
        // Pacoca shares not entitled to the user
        uint256 rewardDebt;
        // Timestamp of last user deposit
        uint256 lastDepositedTime;
    }

    // Addresses
    address constant public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    IERC20 constant public PACOCA = IERC20(0x55671114d774ee99D653D6C12460c780a67f1D18);
    IPacocaVault immutable public AUTO_PACOCA;
    IERC20 immutable public STAKED_TOKEN;

    // Runtime data
    mapping(address => UserInfo) public userInfo; // Info of users
    uint256 public accSharesPerStakedToken; // Accumulated AUTO_PACOCA shares per staked token, times 1e18.

    // Farm info
    IPancakeswapFarm immutable public STAKED_TOKEN_FARM;
    IERC20 immutable public FARM_REWARD_TOKEN;
    uint256 immutable public FARM_PID;
    bool immutable IS_CAKE_STAKING;

    // Settings
    IPancakeRouter01 immutable public router;
    address[] public pathToPacoca; // Path from staked token to PACOCA
    address[] public pathToWbnb; // Path from staked token to WBNB

    address public treasury;
    address public keeper;
    uint256 public keeperFee = 50; // 0.5%
    uint256 public constant keeperFeeUL = 100; // 1%

    address public platform;
    uint256 public platformFee;
    uint256 public constant platformFeeUL = 500; // 5%

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public buyBackRate;
    uint256 public constant buyBackRateUL = 300; // 5%

    uint256 public earlyWithdrawFee = 100; // 1%
    uint256 public constant earlyWithdrawFeeUL = 300; // 3%
    uint256 public constant withdrawFeePeriod = 3 days;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EarlyWithdraw(address indexed user, uint256 amount, uint256 fee);
    event ClaimRewards(address indexed user, uint256 shares, uint256 amount);

    // Setting updates
    event SetPathToPacoca(address[] oldPath, address[] newPath);
    event SetPathToWbnb(address[] oldPath, address[] newPath);
    event SetBuyBackRate(uint256 oldBuyBackRate, uint256 newBuyBackRate);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetKeeper(address oldKeeper, address newKeeper);
    event SetKeeperFee(uint256 oldKeeperFee, uint256 newKeeperFee);
    event SetPlatform(address oldPlatform, address newPlatform);
    event SetPlatformFee(uint256 oldPlatformFee, uint256 newPlatformFee);
    event SetEarlyWithdrawFee(uint256 oldEarlyWithdrawFee, uint256 newEarlyWithdrawFee);

    constructor(
        address _autoPacoca,
        address _stakedToken,
        address _stakedTokenFarm,
        address _farmRewardToken,
        uint256 _farmPid,
        bool _isCakeStaking,
        address _router,
        address[] memory _pathToPacoca,
        address[] memory _pathToWbnb,
        address _owner,
        address _treasury,
        address _keeper,
        address _platform,
        uint256 _buyBackRate,
        uint256 _platformFee
    ) public {
        require(
            _pathToPacoca[0] == address(_farmRewardToken) && _pathToPacoca[_pathToPacoca.length - 1] == address(PACOCA),
            "SweetVault: Incorrect path to PACOCA"
        );

        require(
            _pathToWbnb[0] == address(_farmRewardToken) && _pathToWbnb[_pathToWbnb.length - 1] == WBNB,
            "SweetVault: Incorrect path to WBNB"
        );

        require(_buyBackRate <= buyBackRateUL);
        require(_platformFee <= platformFeeUL);

        AUTO_PACOCA = IPacocaVault(_autoPacoca);
        STAKED_TOKEN = IERC20(_stakedToken);
        STAKED_TOKEN_FARM = IPancakeswapFarm(_stakedTokenFarm);
        FARM_REWARD_TOKEN = IERC20(_farmRewardToken);
        FARM_PID = _farmPid;
        IS_CAKE_STAKING = _isCakeStaking;

        router = IPancakeRouter01(_router);
        pathToPacoca = _pathToPacoca;
        pathToWbnb = _pathToWbnb;

        buyBackRate = _buyBackRate;
        platformFee = _platformFee;

        transferOwnership(_owner);
        treasury = _treasury;
        keeper = _keeper;
        platform = _platform;
    }

    /**
     * @dev Throws if called by any account other than the keeper.
     */
    modifier onlyKeeper() {
        require(keeper == msg.sender, "SweetVault: caller is not the keeper");
        _;
    }

    // 1. Harvest rewards
    // 2. Collect fees
    // 3. Convert rewards to $PACOCA
    // 4. Stake to pacoca auto-compound vault
    function earn(
        uint256 _minPlatformOutput,
        uint256 _minKeeperOutput,
        uint256 _minBurnOutput,
        uint256 _minPacocaOutput
    ) external onlyKeeper {
        if (IS_CAKE_STAKING) {
            STAKED_TOKEN_FARM.leaveStaking(0);
        } else {
            STAKED_TOKEN_FARM.withdraw(FARM_PID, 0);
        }

        uint256 rewardTokenBalance = _rewardTokenBalance();

        // Collect platform fees
        if (platformFee > 0) {
            _swap(
                rewardTokenBalance.mul(platformFee).div(10000),
                _minPlatformOutput,
                pathToWbnb,
                platform
            );
        }

        // Collect keeper fees
        if (keeperFee > 0) {
            _swap(
                rewardTokenBalance.mul(keeperFee).div(10000),
                _minKeeperOutput,
                pathToWbnb,
                treasury
            );
        }

        // Collect Burn fees
        if (buyBackRate > 0) {
            _swap(
                rewardTokenBalance.mul(buyBackRate).div(10000),
                _minBurnOutput,
                pathToPacoca,
                BURN_ADDRESS
            );
        }

        // Convert remaining rewards to PACOCA
        _swap(
            _rewardTokenBalance(),
            _minPacocaOutput,
            pathToPacoca,
            address(this)
        );

        uint256 previousShares = totalAutoPacocaShares();
        uint256 pacocaBalance = _pacocaBalance();

        _approveTokenIfNeeded(
            PACOCA,
            pacocaBalance,
            address(AUTO_PACOCA)
        );

        AUTO_PACOCA.deposit(pacocaBalance);

        uint256 currentShares = totalAutoPacocaShares();

        accSharesPerStakedToken = accSharesPerStakedToken.add(
            currentShares.sub(previousShares).mul(1e18).div(totalStake())
        );
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "SweetVault: amount must be greater than zero");

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
            STAKED_TOKEN_FARM.enterStaking(_amount);
        } else {
            STAKED_TOKEN_FARM.deposit(FARM_PID, _amount);
        }

        user.autoPacocaShares = user.autoPacocaShares.add(
            user.stake.mul(accSharesPerStakedToken).div(1e18).sub(
                user.rewardDebt
            )
        );
        user.stake = user.stake.add(_amount);
        user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);
        user.lastDepositedTime = block.timestamp;

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(_amount > 0, "SweetVault: amount must be greater than zero");
        require(user.stake >= _amount, "SweetVault: withdraw amount exceeds balance");

        if (IS_CAKE_STAKING) {
            STAKED_TOKEN_FARM.leaveStaking(_amount);
        } else {
            STAKED_TOKEN_FARM.withdraw(FARM_PID, _amount);
        }

        uint256 currentAmount = _amount;

        if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
            uint256 currentWithdrawFee = currentAmount.mul(earlyWithdrawFee).div(10000);

            STAKED_TOKEN.safeTransfer(treasury, currentWithdrawFee);

            currentAmount = currentAmount.sub(currentWithdrawFee);

            emit EarlyWithdraw(msg.sender, _amount, currentWithdrawFee);
        }

        user.autoPacocaShares = user.autoPacocaShares.add(
            user.stake.mul(accSharesPerStakedToken).div(1e18).sub(
                user.rewardDebt
            )
        );
        user.stake = user.stake.sub(_amount);
        user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);

        // Withdraw pacoca rewards if user leaves
        if (user.stake == 0 && user.autoPacocaShares > 0) {
            _claimRewards(user.autoPacocaShares, false);
        }

        STAKED_TOKEN.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount);
    }

    function claimRewards(uint256 _shares) external nonReentrant {
        _claimRewards(_shares, true);
    }

    function _claimRewards(uint256 _shares, bool _update) private {
        UserInfo storage user = userInfo[msg.sender];

        if (_update) {
            user.autoPacocaShares = user.autoPacocaShares.add(
                user.stake.mul(accSharesPerStakedToken).div(1e18).sub(
                    user.rewardDebt
                )
            );

            user.rewardDebt = user.stake.mul(accSharesPerStakedToken).div(1e18);
        }

        require(user.autoPacocaShares >= _shares, "SweetVault: claim amount exceeds balance");

        user.autoPacocaShares = user.autoPacocaShares.sub(_shares);

        uint256 pacocaBalanceBefore = _pacocaBalance();

        AUTO_PACOCA.withdraw(_shares);

        uint256 withdrawAmount = _pacocaBalance().sub(pacocaBalanceBefore);

        _safePACOCATransfer(msg.sender, withdrawAmount);

        emit ClaimRewards(msg.sender, _shares, withdrawAmount);
    }

    function getExpectedOutputs() external view returns (
        uint256 platformOutput,
        uint256 keeperOutput,
        uint256 burnOutput,
        uint256 pacocaOutput
    ) {
        uint256 wbnbOutput = _getExpectedOutput(pathToWbnb);
        uint256 pacocaOutputWithoutFees = _getExpectedOutput(pathToPacoca);

        platformOutput = wbnbOutput.mul(platformFee).div(10000);
        keeperOutput = wbnbOutput.mul(keeperFee).div(10000);
        burnOutput = pacocaOutputWithoutFees.mul(buyBackRate).div(10000);

        pacocaOutput = pacocaOutputWithoutFees.sub(
            pacocaOutputWithoutFees.mul(platformFee).div(10000).add(
                pacocaOutputWithoutFees.mul(keeperFee).div(10000)
            ).add(
                pacocaOutputWithoutFees.mul(buyBackRate).div(10000)
            )
        );
    }

    function _getExpectedOutput(
        address[] memory _path
    ) private view returns (uint256) {
        uint256 rewards = _rewardTokenBalance().add(
            STAKED_TOKEN_FARM.pendingCake(FARM_PID, address(this))
        );

        uint256[] memory amounts = router.getAmountsOut(rewards, _path);

        return amounts[amounts.length.sub(1)];
    }

    function balanceOf(
        address _user
    ) external view returns (
        uint256 stake,
        uint256 pacoca,
        uint256 autoPacocaShares
    ) {
        UserInfo memory user = userInfo[_user];

        uint256 pendingShares = user.stake.mul(accSharesPerStakedToken).div(1e18).sub(
            user.rewardDebt
        );

        stake = user.stake;
        autoPacocaShares = user.autoPacocaShares.add(pendingShares);
        pacoca = autoPacocaShares.mul(AUTO_PACOCA.getPricePerFullShare()).div(1e18);
    }

    function _approveTokenIfNeeded(
        IERC20 _token,
        uint256 _amount,
        address _spender
    ) private {
        if (_token.allowance(address(this), _spender) < _amount) {
            _token.safeIncreaseAllowance(_spender, _amount);
        }
    }

    function _rewardTokenBalance() private view returns (uint256) {
        return FARM_REWARD_TOKEN.balanceOf(address(this));
    }

    function _pacocaBalance() private view returns (uint256) {
        return PACOCA.balanceOf(address(this));
    }

    function totalStake() public view returns (uint256) {
        return STAKED_TOKEN_FARM.userInfo(FARM_PID, address(this));
    }

    function totalAutoPacocaShares() public view returns (uint256) {
        (uint256 shares, , ,) = AUTO_PACOCA.userInfo(address(this));

        return shares;
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

    function _swap(
        uint256 _inputAmount,
        uint256 _minOutputAmount,
        address[] memory _path,
        address _to
    ) private {
        _approveTokenIfNeeded(
            FARM_REWARD_TOKEN,
            _inputAmount,
            address(router)
        );

        router.swapExactTokensForTokens(
            _inputAmount,
            _minOutputAmount,
            _path,
            _to,
            block.timestamp
        );
    }

    function setPathToPacoca(address[] memory _path) external onlyOwner {
        require(
            _path[0] == address(FARM_REWARD_TOKEN) && _path[_path.length - 1] == address(PACOCA),
            "SweetVault: Incorrect path to PACOCA"
        );

        address[] memory oldPath = pathToPacoca;

        pathToPacoca = _path;

        emit SetPathToPacoca(oldPath, pathToPacoca);
    }

    function setPathToWbnb(address[] memory _path) external onlyOwner {
        require(
            _path[0] == address(FARM_REWARD_TOKEN) && _path[_path.length - 1] == WBNB,
            "SweetVault: Incorrect path to WBNB"
        );

        address[] memory oldPath = pathToWbnb;

        pathToWbnb = _path;

        emit SetPathToWbnb(oldPath, pathToWbnb);
    }

    function setTreasury(address _treasury) external onlyOwner {
        address oldTreasury = treasury;

        treasury = _treasury;

        emit SetTreasury(oldTreasury, treasury);
    }

    function setKeeper(address _keeper) external onlyOwner {
        address oldKeeper = keeper;

        keeper = _keeper;

        emit SetKeeper(oldKeeper, keeper);
    }

    function setKeeperFee(uint256 _keeperFee) external onlyOwner {
        require(_keeperFee <= keeperFeeUL, "SweetVault: Keeper fee too high");

        uint256 oldKeeperFee = keeperFee;

        keeperFee = _keeperFee;

        emit SetKeeperFee(oldKeeperFee, keeperFee);
    }

    function setPlatform(address _platform) external onlyOwner {
        address oldPlatform = platform;

        platform = _platform;

        emit SetPlatform(oldPlatform, platform);
    }

    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        require(_platformFee <= platformFeeUL, "SweetVault: Platform fee too high");

        uint256 oldPlatformFee = platformFee;

        platformFee = _platformFee;

        emit SetPlatformFee(oldPlatformFee, platformFee);
    }

    function setBuyBackRate(uint256 _buyBackRate) external onlyOwner {
        require(
            _buyBackRate <= buyBackRateUL,
            "SweetVault: Buy back rate too high"
        );

        uint256 oldBuyBackRate = buyBackRate;

        buyBackRate = _buyBackRate;

        emit SetBuyBackRate(oldBuyBackRate, buyBackRate);
    }

    function setEarlyWithdrawFee(uint256 _earlyWithdrawFee) external onlyOwner {
        require(
            _earlyWithdrawFee <= earlyWithdrawFeeUL,
            "SweetVault: Early withdraw fee too high"
        );

        uint256 oldEarlyWithdrawFee = earlyWithdrawFee;

        earlyWithdrawFee = _earlyWithdrawFee;

        emit SetEarlyWithdrawFee(oldEarlyWithdrawFee, earlyWithdrawFee);
    }
}
