// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
 import "./IERC20.sol";

 contract Staking {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;
    
    uint public duration;
    uint public finishAt; 
    uint public updatedAt;
    uint public rewardRate;
    uint public rewardsPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    modifier onlyOwner () {
        require(msg.sender == owner ,"not owner");
        _;
    }

    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    modifier updateReward (address _staker) {
        rewardsPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_staker != address(0)) {
            rewards[_staker] = earned(_staker);
            userRewardPerTokenPaid[_staker] = rewardsPerTokenStored;
            _;
        }
    }

    constructor(address _stakingToken, address _rewardsToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function setRewardsDuration(uint _duration) external onlyOwner{
        require(finishAt < block.timestamp, "reward duration not reached");
        duration = _duration;
    }
    function notifyRewardAmount(uint _amount) external onlyOwner {
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) /duration;
        }
       
        require(rewardRate > 0, "reward rate is 0");
        require( rewardRate * duration <= rewardsToken.balanceOf(address(this)),
        "reward amount is greater than balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0,"amount has to be greater than 0");        
        balanceOf[msg.sender] = balanceOf[msg.sender] + _amount;
        totalSupply = totalSupply + _amount;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount is 0");        
        totalSupply = totalSupply - _amount;
        stakingToken.transfer(msg.sender, _amount); 
        balanceOf[msg.sender] = balanceOf[msg.sender] - _amount;       
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardsPerTokenStored;
        }
        return rewardsPerTokenStored + (rewardRate * (lastTimeRewardApplicable() -updatedAt)* 1e18) /totalSupply;
    }

    function earned(address _account) public view returns (uint) {
        return (balanceOf[_account] * 
            (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18
        + rewards[_account];
    }

    
    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y? x:y;
    }
 }
