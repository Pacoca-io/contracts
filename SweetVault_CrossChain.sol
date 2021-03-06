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

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IFarm.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPacocaVault.sol";

contract SweetVault_CrossChain is OwnableUpgradeable, ReentrancyGuardUpgradeable {
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
    address public wNATIVE;
    IERC20 public wPACOCA;
    IERC20 public STAKED_TOKEN;

    // Runtime data
    mapping(address => UserInfo) public userInfo; // Info of users
    uint256 public accSharesPerStakedToken; // Accumulated wPACOCA shares per staked token, times 1e18.

    // Farm info
    IFarm public STAKED_TOKEN_FARM;
    IERC20 public FARM_REWARD_TOKEN;
    uint256 public FARM_PID;
    bool public IS_BISWAP;

    // Settings
    IPancakeRouter02 public router;
    address[] public pathToWPacoca; // Path from staked token to wPACOCA
    address[] public pathToWNative; // Path from staked token to wNative

    address public treasury;
    address public keeper;

    address public platform;
    uint256 public platformFee;
    uint256 public constant platformFeeUL = 1000;

    uint256 public earlyWithdrawFee;
    uint256 public constant earlyWithdrawFeeUL = 300;
    uint256 public constant withdrawFeePeriod = 3 days;

    // User events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EarlyWithdraw(address indexed user, uint256 amount, uint256 fee);
    event ClaimRewards(address indexed user, uint256 shares);

    // Setting events
    event SetPathToWPacoca(address[] oldPath, address[] newPath);
    event SetPathToWNative(address[] oldPath, address[] newPath);
    event SetTreasury(address oldTreasury, address newTreasury);
    event SetKeeper(address oldKeeper, address newKeeper);
    event SetPlatform(address oldPlatform, address newPlatform);
    event SetPlatformFee(uint256 oldPlatformFee, uint256 newPlatformFee);
    event SetEarlyWithdrawFee(uint256 oldEarlyWithdrawFee, uint256 newEarlyWithdrawFee);

    function initialize(
        address _wNATIVE,
        address _wPACOCA,
        address _stakedToken,
        address _stakedTokenFarm,
        address _farmRewardToken,
        uint256 _farmPid,
        address _router,
        address[] memory _pathToWPacoca,
        address[] memory _pathToWNative,
        address _owner,
        address _treasury,
        address _keeper,
        address _platform
    ) public initializer {
        require(
            _pathToWPacoca[0] == address(_farmRewardToken) && _pathToWPacoca[_pathToWPacoca.length - 1] == address(wPACOCA),
            "SweetVault: Incorrect path to wPACOCA"
        );

        require(
            _pathToWNative[0] == address(_farmRewardToken) && _pathToWNative[_pathToWNative.length - 1] == wNATIVE,
            "SweetVault: Incorrect path to wNative"
        );

        wNATIVE = _wNATIVE;
        wPACOCA = IERC20(_wPACOCA);
        STAKED_TOKEN = IERC20(_stakedToken);
        STAKED_TOKEN_FARM = IFarm(_stakedTokenFarm);
        FARM_REWARD_TOKEN = IERC20(_farmRewardToken);
        FARM_PID = _farmPid;
        IS_BISWAP = _stakedTokenFarm == 0xDbc1A13490deeF9c3C12b44FE77b503c1B061739;

        router = IPancakeRouter02(_router);
        pathToWPacoca = _pathToWPacoca;
        pathToWNative = _pathToWNative;

        earlyWithdrawFee = 100;
        platformFee = 550;

        __ReentrancyGuard_init();
        __Ownable_init();
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
        uint256 _minPacocaOutput
    ) external virtual onlyKeeper {
        STAKED_TOKEN_FARM.withdraw(FARM_PID, 0);

        // Collect platform fees
        _swap(
            _rewardTokenBalance().mul(platformFee).div(10000),
            _minPlatformOutput,
            pathToWNative,
            platform
        );

        uint256 initialShares = totalAutoPacocaShares();

        // Convert remaining rewards to wPACOCA
        _swap(
            _rewardTokenBalance(),
            _minPacocaOutput,
            pathToWPacoca,
            address(this)
        );

        uint256 finalShares = totalAutoPacocaShares();

        accSharesPerStakedToken = accSharesPerStakedToken.add(
            finalShares.sub(initialShares).mul(1e18).div(totalStake())
        );
    }

    function deposit(uint256 _amount) external virtual nonReentrant {
        require(_amount > 0, "SweetVault: amount must be greater than zero");

        UserInfo storage user = userInfo[msg.sender];

        STAKED_TOKEN.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _approveTokenIfNeeded(
            STAKED_TOKEN,
            _amount,
            address(STAKED_TOKEN_FARM)
        );

        _deposit(_amount);

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

    function _deposit(uint256 _amount) internal virtual {
        STAKED_TOKEN_FARM.deposit(FARM_PID, _amount);
    }

    function withdraw(uint256 _amount) external virtual nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(_amount > 0, "SweetVault: amount must be greater than zero");
        require(user.stake >= _amount, "SweetVault: withdraw amount exceeds balance");

        STAKED_TOKEN_FARM.withdraw(FARM_PID, _amount);

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

    function _claimRewards(uint256 _shares, bool _update) internal {
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

        _safePACOCATransfer(msg.sender, _shares);

        emit ClaimRewards(msg.sender, _shares);
    }

    function getExpectedOutputs() external view returns (
        uint256 platformOutput,
        uint256 pacocaOutput
    ) {
        uint256 wNativeOutput = _getExpectedOutput(pathToWNative);
        uint256 pacocaOutputWithoutFees = _getExpectedOutput(pathToWPacoca);

        platformOutput = wNativeOutput.mul(platformFee).div(10000);
        pacocaOutput = pacocaOutputWithoutFees.sub(
            pacocaOutputWithoutFees.mul(platformFee).div(10000)
        );
    }

    function _getExpectedOutput(
        address[] memory _path
    ) internal virtual view returns (uint256) {
        uint256 pending;

        if (IS_BISWAP) {
            pending = STAKED_TOKEN_FARM.pendingBSW(FARM_PID, address(this));
        } else {
            pending = STAKED_TOKEN_FARM.pendingCake(FARM_PID, address(this));
        }

        uint256 rewards = _rewardTokenBalance().add(pending);

        if (rewards == 0) {
            return 0;
        }

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
        // Cannot be calculated outside bsc
        pacoca = 0;
    }

    function _approveTokenIfNeeded(
        IERC20 _token,
        uint256 _amount,
        address _spender
    ) internal {
        if (_token.allowance(address(this), _spender) < _amount) {
            _token.safeIncreaseAllowance(_spender, _amount);
        }
    }

    function _rewardTokenBalance() internal view returns (uint256) {
        return FARM_REWARD_TOKEN.balanceOf(address(this));
    }

    function totalStake() public view returns (uint256) {
        return STAKED_TOKEN_FARM.userInfo(FARM_PID, address(this));
    }

    function totalAutoPacocaShares() public view returns (uint256) {
        return wPACOCA.balanceOf(address(this));
    }

    // Safe PACOCA transfer function, just in case if rounding error causes pool to not have enough
    function _safePACOCATransfer(address _to, uint256 _amount) internal {
        uint256 balance = totalAutoPacocaShares();

        if (_amount > balance) {
            wPACOCA.transfer(_to, balance);
        } else {
            wPACOCA.transfer(_to, _amount);
        }
    }

    function _swap(
        uint256 _inputAmount,
        uint256 _minOutputAmount,
        address[] memory _path,
        address _to
    ) internal virtual {
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

    function setPathToWPacoca(address[] memory _path) external onlyOwner {
        require(
            _path[0] == address(FARM_REWARD_TOKEN) && _path[_path.length - 1] == address(wPACOCA),
            "SweetVault: Incorrect path to PACOCA"
        );

        address[] memory oldPath = pathToWPacoca;

        pathToWPacoca = _path;

        emit SetPathToWPacoca(oldPath, pathToWPacoca);
    }

    function setPathToWNative(address[] memory _path) external onlyOwner {
        require(
            _path[0] == address(FARM_REWARD_TOKEN) && _path[_path.length - 1] == wNATIVE,
            "SweetVault: Incorrect path to wNATIVE"
        );

        address[] memory oldPath = pathToWNative;

        pathToWNative = _path;

        emit SetPathToWNative(oldPath, pathToWNative);
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
