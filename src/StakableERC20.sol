// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title StakableERC20
/// @author insomnia.exe
/// @notice ERC20 token with staking functionality. This contract has owner, owner can change
/// percent of stake reward and mint tokens to any address. This contract has referal system,
/// referal can be set on stake and referal will get percent of stake reward.
/// This contract is just example of staking ERC20 token, it is not audited and not ready for production.
contract StakableERC20 is ERC20, Ownable {
  error StakableERC20__InvalidAmount();
  error StakableERC20__NotEnoughBalance();
  error StakableERC20__RewardAlreadyClaimed();
  error StakableERC20__StakeNotExists();

  event Staked(
    uint256 stakeId,
    address indexed user,
    address indexed referal,
    uint256 startTimestamp,
    uint256 amount,
    uint256 percent
  );
  event Claimed(
    uint256 stakeId,
    address indexed user,
    address indexed referal,
    uint256 reward,
    uint256 referalReward,
    uint256 endTimestamp
  );

  struct StakeInfo {
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 amount;
    uint256 claimed;
    uint256 percent;
    address referal;
  }

  uint256 public constant STAKE_PERIOD = 365 days;
  uint256 public s_referalPercent;
  uint256 public s_stakePercent;

  mapping(address => StakeInfo[]) public s_stakes;

  constructor(uint256 _referalPercent, uint256 _stakePercent) Ownable() ERC20("GameCoin", "GMC") {
    s_referalPercent = _referalPercent;
    s_stakePercent = _stakePercent;
  }

  /// @notice this function can be called only by owner
  /// @param _to destination of user to mint address
  /// @param _amount amount of tokens to mint
  function mintTo(address _to, uint256 _amount) external onlyOwner {
    _mint(_to, _amount);
  }

  /// @notice this function can be called only by owner
  /// @param _percent percent of stake reward
  function setStakePercent(uint256 _percent) external onlyOwner {
    s_stakePercent = _percent;
  }

  /// @notice Check Effect Integration
  /// @notice this function can be called by anyone
  /// @param _amount amount of tokens to stake
  /// @param _referal referal address, provide zero address if no referal
  function stake(uint256 _amount, address _referal) external {
    if (_amount == 0) revert StakableERC20__InvalidAmount();
    if (balanceOf(msg.sender) < _amount) revert StakableERC20__NotEnoughBalance();

    _transfer(_msgSender(), address(this), _amount);
    StakeInfo memory stakeInfo = StakeInfo({
      startTimestamp: block.timestamp,
      endTimestamp: 0,
      amount: _amount,
      claimed: 0,
      percent: s_stakePercent,
      referal: _referal
    });
    s_stakes[msg.sender].push(stakeInfo);

    emit Staked(
      s_stakes[msg.sender].length - 1,
      msg.sender,
      _referal,
      stakeInfo.startTimestamp,
      stakeInfo.amount,
      stakeInfo.percent
      );
  }

  /// @notice This method just returns all stakes of user (claimed and not claimed)
  function getStakes() external view returns (StakeInfo[] memory) {
    return s_stakes[msg.sender];
  }

  /// @notice This methods returns stake of user by index
  function getStake(uint256 _index) external view returns (StakeInfo memory) {
    return s_stakes[msg.sender][_index];
  }

  /// @notice This method calculates reward of stake and mints it to user and referal(optionally)
  /// @param _index index of stake
  function claimStakeReward(uint256 _index) external {
    StakeInfo storage stakeInfo = s_stakes[msg.sender][_index];
    if (stakeInfo.amount == 0) {
      revert StakableERC20__StakeNotExists();
    }
    if (stakeInfo.endTimestamp != 0) {
      revert StakableERC20__RewardAlreadyClaimed();
    }

    (uint256 reward, uint256 referalReward) = calculateReward(stakeInfo);
    stakeInfo.claimed += reward + referalReward;

    _mint(msg.sender, reward);
    if (stakeInfo.referal != address(0)) {
      _mint(stakeInfo.referal, referalReward);
    }

    emit Claimed(_index, msg.sender, stakeInfo.referal, reward, referalReward, block.timestamp);
  }

  /// @notice This method calculates reward of stake and referal reward
  function calculateReward(StakeInfo memory _stakeInfo) public view returns (uint256 reward, uint256 referalReward) {
    uint256 endTimestamp = block.timestamp;
    uint256 duration = endTimestamp - _stakeInfo.startTimestamp;

    reward = (_stakeInfo.amount * _stakeInfo.percent * duration) / (100 * STAKE_PERIOD);
    referalReward = 0;
    if (_stakeInfo.referal != address(0)) {
      referalReward = (reward * s_referalPercent) / 100;
      reward -= referalReward;
    }
  }
}
