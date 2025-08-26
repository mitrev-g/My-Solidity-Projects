//SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract StakingPool is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for ERC20;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimedRewards(address indexed user, uint256 amount);

    uint256 public constant PRECISION = 1e12;

    ERC20 public stakingToken; // staked token
    ERC20 public rewardToken; // reward token
    uint256 public startBlock; // block.number - beginning of staking period
    uint256 public endBlock; // block.number - end of staking period
    uint256 public maxRewardAmount; // reward amount

    uint256 private stakedTokenSupply; // total staked token supply

    uint256 public lastUpdatedBlock; // block.number - last time the Pool Params were updated was updated
    uint256 public rewardPerBlock; // reward per block

    uint256 public accruedRewardPerStakedToken; // accrued reward per staked token, share = staked token
    uint256 public totalRewardsPaid;

    struct User {
        uint256 stakedTokenBalance; // staked token balance
        uint256 rewardDebt; // reward debt ==
    }

    mapping(address => User) public users;

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _maxRewardAmount
    ) {
        require(_startBlock >= block.number, "Start block must be in the future");
        require(_endBlock > _startBlock, "End block must be greater than start block");
        stakingToken = ERC20(_stakingToken);
        rewardToken = ERC20(_rewardToken);

        startBlock = _startBlock;
        endBlock = _endBlock;
        maxRewardAmount = _maxRewardAmount;
        rewardPerBlock = (_maxRewardAmount) / (endBlock - startBlock);
        lastUpdatedBlock = block.number;
    }

    function fund(uint256 amount) external onlyOwner {
        require(amount == maxRewardAmount, "Amount must be equal to reward amount");
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _updatePool() internal {
        if (block.number <= lastUpdatedBlock) {
            return;
        }
        if (stakedTokenSupply == 0) {
            lastUpdatedBlock = block.number;
            return;
        }
        uint256 rewardAmount = rewardPerBlock * _blockPassed(lastUpdatedBlock, block.number);
        accruedRewardPerStakedToken += (rewardAmount * PRECISION) / stakedTokenSupply;
        lastUpdatedBlock = block.number;
    }

    function _blockPassed(uint256 from, uint256 to) internal view returns (uint256) {
        if (to <= endBlock) {
            return to - from;
        } else if (from >= endBlock) {
            return 0;
        } else {
            return endBlock - from;
        }
    }

    function deposit(uint256 amount) external nonReentrant {
        require(block.number >= startBlock, "Pool is not active");
        require(block.number < endBlock, "Pool is not active");
        User storage user = users[msg.sender];
        _updatePool();
        if (user.stakedTokenBalance > 0) {
            uint256 pendingRewards =
                (user.stakedTokenBalance * accruedRewardPerStakedToken) / PRECISION - user.rewardDebt;
            if (pendingRewards > 0) {
                rewardToken.safeTransfer(msg.sender, pendingRewards);
                totalRewardsPaid += pendingRewards;
                emit ClaimedRewards(msg.sender, pendingRewards);
            }
        }
        if (amount > 0) {
            user.stakedTokenBalance += amount;
            stakedTokenSupply += amount;

            stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        }
        user.rewardDebt = (user.stakedTokenBalance * accruedRewardPerStakedToken) / PRECISION;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        User storage user = users[msg.sender];
        require(amount <= user.stakedTokenBalance, "Not enough staked tokens");
        _updatePool();
        uint256 pendingRewards = (user.stakedTokenBalance * accruedRewardPerStakedToken) / PRECISION - user.rewardDebt;
        if (pendingRewards > 0) {
            rewardToken.safeTransfer(msg.sender, pendingRewards);
            totalRewardsPaid += pendingRewards;

            emit ClaimedRewards(msg.sender, pendingRewards);
        }
        if (amount > 0) {
            user.stakedTokenBalance -= amount;
            stakedTokenSupply -= amount;
            stakingToken.safeTransfer(msg.sender, amount);
        }
        user.rewardDebt = (user.stakedTokenBalance * accruedRewardPerStakedToken) / PRECISION;

        emit Withdraw(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        User storage user = users[msg.sender];
        _updatePool();
        uint256 pendingRewards = (user.stakedTokenBalance * accruedRewardPerStakedToken) / PRECISION - user.rewardDebt;
        if (pendingRewards > 0) {
            rewardToken.safeTransfer(msg.sender, pendingRewards);

            totalRewardsPaid += pendingRewards;

            emit ClaimedRewards(msg.sender, pendingRewards);
        }
        user.rewardDebt = (user.stakedTokenBalance * accruedRewardPerStakedToken) / PRECISION;
    }
}
