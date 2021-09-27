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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./BnbStorage.sol";

contract BnbVault is Ownable, ReentrancyGuard {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct UserInfo {
        // How many assets the user has provided.
        uint stake;
        // Bnb not entitled to the user
        uint rewardDebt;
        // Timestamp of last user deposit
        uint lastDepositedTime;
    }

    IERC20 public immutable PACOCA;
    IERC20 public immutable WBNB;
    BnbStorage public immutable BNB_STORAGE;
    address public treasury;

    mapping(address => UserInfo) public userInfo; // Info of users
    uint public accBnbPerStakedToken; // Accumulated BNB per staked token, times 1e18.

    uint public earlyWithdrawFee = 100; // 1%
    uint public constant earlyWithdrawFeeUL = 300; // 3%
    uint public constant withdrawFeePeriod = 3 days;

    event Deposit(address indexed user, uint amount);
    event Withdraw(address indexed user, uint amount);
    event EarlyWithdraw(address indexed user, uint amount, uint fee);
    event Collected(uint amount, uint timestamp);

    event SetTreasury(address oldTreasury, address newTreasury);
    event SetEarlyWithdrawFee(uint oldEarlyWithdrawFee, uint newEarlyWithdrawFee);

    constructor (address _pacoca, address _wbnb, address _bnbStorage, address _treasury) public {
        PACOCA = IERC20(_pacoca);
        WBNB = IERC20(_wbnb);
        BNB_STORAGE = BnbStorage(_bnbStorage);
        treasury = _treasury;
    }

    function deposit(uint _amount) external nonReentrant {
        _collect();

        UserInfo storage user = userInfo[msg.sender];

        // Claim pending rewards
        if (user.stake > 0) {
            uint pending = user.stake.mul(accBnbPerStakedToken).div(1e18).sub(
                user.rewardDebt
            );

            if (pending > 0) {
                WBNB.safeTransfer(msg.sender, pending);
            }
        }

        if (_amount > 0) {
            PACOCA.safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );

            user.stake = user.stake.add(_amount);
            user.lastDepositedTime = block.timestamp;
        }

        user.rewardDebt = user.stake.mul(accBnbPerStakedToken).div(1e18);

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint _amount) public nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(user.stake > 0, "BnbVault::withdraw: User has no stake");

        // Claim pending rewards
        uint pending = user.stake.mul(accBnbPerStakedToken).div(1e18).sub(
            user.rewardDebt
        );

        if (pending > 0) {
            WBNB.safeTransfer(msg.sender, pending);
        }

        // Withdraw staked tokens
        uint amount = _amount > user.stake ? user.stake : _amount;

        if (amount > 0) {
            user.stake = user.stake.sub(amount);

            if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
                uint currentWithdrawFee = amount.mul(earlyWithdrawFee).div(10000);

                PACOCA.safeTransfer(treasury, currentWithdrawFee);

                amount = amount.sub(currentWithdrawFee);

                emit EarlyWithdraw(msg.sender, amount, currentWithdrawFee);
            }

            PACOCA.safeTransfer(msg.sender, amount);
        }

        user.rewardDebt = user.stake.mul(accBnbPerStakedToken).div(1e18);

        emit Withdraw(msg.sender, amount);
    }

    function pendingRewards(address _user) external view returns (uint) {
        UserInfo storage user = userInfo[_user];

        return user.stake.mul(accBnbPerStakedToken).div(1e18).sub(
            user.rewardDebt
        );
    }

    function _collect() private {
        if (BNB_STORAGE.balance() == 0) {
            return;
        }

        uint initialBalance = bnbBalance();

        BNB_STORAGE.collect();

        uint amountCollected = bnbBalance().sub(initialBalance);

        accBnbPerStakedToken = accBnbPerStakedToken.add(
            amountCollected.mul(1e18).div(pacocaBalance())
        );

        emit Collected(amountCollected, block.timestamp);
    }

    function bnbBalance() public view returns (uint) {
        return WBNB.balanceOf(address(this));
    }

    function pacocaBalance() public view returns (uint) {
        return PACOCA.balanceOf(address(this));
    }

    function setTreasury(address _treasury) external onlyOwner {
        address oldTreasury = treasury;

        treasury = _treasury;

        emit SetTreasury(oldTreasury, treasury);
    }

    function setEarlyWithdrawFee(uint _earlyWithdrawFee) external onlyOwner {
        require(
            _earlyWithdrawFee <= earlyWithdrawFeeUL,
            "BnbVault::setEarlyWithdrawFee: Early withdraw fee too high"
        );

        uint oldEarlyWithdrawFee = earlyWithdrawFee;

        earlyWithdrawFee = _earlyWithdrawFee;

        emit SetEarlyWithdrawFee(oldEarlyWithdrawFee, earlyWithdrawFee);
    }
}
