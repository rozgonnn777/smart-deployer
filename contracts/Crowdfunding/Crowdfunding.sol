//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "../UtilityContract/AbstractUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Crowdfunding - Utility contract for raising funds with vesting-based fund release.
/// @author rozghon7.
/// @notice This contract allows users to contribute funds towards a fundraising goal, with vesting logic on success.
contract Crowdfunding is AbstractUtilityContract, Ownable {
    /// @notice VestingWallet instance for fundraiser.
    VestingWallet public vestingWallet;
    /// @notice Address of the fundraiser who will receive vested funds.
    address fundraiser;
    /// @notice Duration of the vesting schedule in seconds.
    uint256 vestingTime;
    /// @notice Target amount to reach for starting vesting.
    uint256 goal;
    /// @notice Total current contributions in pool.
    uint256 donationPool;
    /// @notice Timestamp when fundraising goal was reached.
    uint256 startTimestamp;
    /// @notice Flag indicating if the goal has been reached.
    bool poolReached;
    /// @notice Flag indicating if vesting has started.
    bool vestingStarted;

    /// @notice Stores user contribution history.
    mapping(address => uint256) donationsHistory;

    /// @notice Emitted when a contribution is received.
    event ContributionReceived(address _user, uint256 _amount, uint256 _timestamp);
    /// @notice Emitted when vesting starts.
    event VestingStarted(address _VestingContractAddress, uint256 _timestamp);
    /// @notice Emitted when a refund is processed.
    event RefundProcessed(address _user, uint256 _amount, uint256 _timestamp);
    /// @notice Emitted when the fundraiser withdraws funds from vesting.
    event FundsWithdrawnFromVesting(address _fundraiser, uint256 _timestamp);

    /// @dev Reverts if the contribution value is invalid.
    error InvalidValue();
    /// @dev Reverts if trying to refund after the pool goal is reached.
    error PoolHasReachedAndYouCantRefund();
    /// @dev Reverts if user has nothing to refund.
    error NothingToRefund();
    /// @dev Reverts if refund amount exceeds user's balance.
    error AmountTooHigh();
    /// @dev Reverts if pool already reached.
    error PoolHasReached();
    /// @dev Reverts if ETH transfer to vesting failed.
    error TransactionFailed();
    /// @dev Reverts if caller is not the fundraiser.
    error OnlyFundraiserAllowed();
    /// @dev Reverts if vesting has not started.
    error VestingNotStarted();

    /// @notice Initializes Ownable with deployer.
    constructor() payable Ownable(msg.sender) {}

    /// @notice Allows a user to contribute to the fundraising pool.
    /// @dev Reverts if pool already reached or goal would be exceeded.
    function contribute() public payable {
        require(poolReached == false, PoolHasReached());
        require(donationPool + msg.value <= goal, InvalidValue());

        donationPool = donationPool + msg.value;
        donationsHistory[msg.sender] = donationsHistory[msg.sender] + msg.value;

        startVestingCheck();

        emit ContributionReceived(msg.sender, msg.value, block.timestamp);
    }

    /// @notice Starts the vesting schedule if fundraising goal is reached.
    /// @dev Deploys VestingWallet and sends contract balance.
    /// @return Address of the deployed VestingWallet contract.
    function startVestingCheck() public returns (address) {
        if (donationPool == goal) {
            startTimestamp = block.timestamp;
            poolReached = true;
            vestingStarted = true;

            vestingWallet = new VestingWallet(fundraiser, uint64(startTimestamp), uint64(vestingTime));

            (bool success,) = address(vestingWallet).call{value: address(this).balance}("");
            require(success, TransactionFailed());
        }

        emit VestingStarted(address(vestingWallet), block.timestamp);
        return address(vestingWallet);
    }

    /// @notice Allows a contributor to request a refund before pool is full.
    /// @param _value Amount to refund.
    function refund(uint256 _value) external {
        require(poolReached == false, PoolHasReachedAndYouCantRefund());

        uint256 userFunds = donationsHistory[msg.sender];
        require(userFunds > 0, NothingToRefund());
        require(userFunds >= _value, AmountTooHigh());

        payable(msg.sender).transfer(_value);

        donationPool -= _value;
        donationsHistory[msg.sender] -= _value;

        emit RefundProcessed(msg.sender, _value, block.timestamp);
    }

    /// @inheritdoc IUtilityContract
    function initialize(bytes memory _initData) external override notInitialized returns (bool) {
        (address _deployManager, uint256 _goal, address _fundraiser, uint256 _vestingTime, address _owner) =
            abi.decode(_initData, (address, uint256, address, uint256, address));

        goal = _goal;
        fundraiser = _fundraiser;
        vestingTime = _vestingTime;
        Ownable.transferOwnership(_owner);
        setDeployManager(_deployManager);

        initialized = true;
        return true;
    }

    /// @notice Encodes initialization parameters to bytes.
    /// @param _deployManager Address of DeployManager.
    /// @param _goal Target amount to reach.
    /// @param _fundraiser Address who receives funds via vesting.
    /// @param _vestingTime Duration of the vesting schedule.
    /// @param _owner New owner of the contract.
    /// @return Encoded initialization payload.
    function getInitData(
        address _deployManager,
        uint256 _goal,
        address _fundraiser,
        uint64 _vestingTime,
        address _owner
    ) external pure returns (bytes memory) {
        return abi.encode(_deployManager, _goal, _fundraiser, _vestingTime, _owner);
    }

    /// @notice Allows the fundraiser to withdraw vested tokens.
    function withdraw() external {
        require(msg.sender == fundraiser, OnlyFundraiserAllowed());
        require(address(vestingWallet) != address(0), VestingNotStarted());

        vestingWallet.release(payable(fundraiser));

        emit FundsWithdrawnFromVesting(fundraiser, block.timestamp);
    }

    /// @notice Handles plain ether transfers as a fallback contribution method.
    receive() external payable {
        require(poolReached == false, PoolHasReached());
        contribute();
    }
}
