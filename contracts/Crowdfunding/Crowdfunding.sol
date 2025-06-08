//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Crowdfunding is Ownable, IUtilityContract{

    VestingWallet public vestingWallet;
    address fundraiser;
    uint256 vestingTime;
    uint256 goal;
    uint256 donationPool;
    uint256 startTimestamp;
    bool poolReached;
    bool vestingStarted;
    bool initialized;

    constructor() Ownable(msg.sender) {}

    mapping (address => uint256) donationsHistory;

    event ContributionReceived(address _user, uint256 _amount, uint256 _timestamp);
    event VestingStarted(address _VestingContractAddress, uint256 _timestamp);
    event RefundProcessed(address _user, uint256 _amount, uint256 _timestamp);
    event FundsWithdrawnFromVesting(address _fundraiser, uint256 _timestamp);

    error InvalidValue();
    error PoolHasReachedAndYouCantRefund();
    error NothingToRefund();
    error AmountTooHigh();
    error PoolHasReached();
    error TransactionFailed();
    error AlreadyInitialized();
    error OnlyFundraiserAllowed();
    error VestingNotStarted();

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function contribute() public payable {
        
        require(poolReached == false, PoolHasReached());
        require(donationPool + msg.value <= goal, InvalidValue());
        donationPool += msg.value;
        donationsHistory[msg.sender] += msg.value;

        startVestingCheck();

        emit ContributionReceived(msg.sender, msg.value, block.timestamp);
    }

    function startVestingCheck() public returns(address) {
        
        if (donationPool == goal){
            startTimestamp = block.timestamp;
            poolReached = true;
            vestingStarted = true;
            
            vestingWallet = new VestingWallet(fundraiser, uint64(startTimestamp), uint64(vestingTime));
            
            (bool success, ) = address(vestingWallet).call{value : address(this).balance}("");
            require(success, TransactionFailed());
        }

        emit VestingStarted(address(vestingWallet), block.timestamp);
        
        return address(vestingWallet);
    }

    function refund(uint256 _value) external {
        
        require(poolReached == false, PoolHasReachedAndYouCantRefund());
        
        uint256 userFunds = donationsHistory[msg.sender];
        require(userFunds > 0, NothingToRefund());
        require(userFunds >= _value, AmountTooHigh());
        payable (msg.sender).transfer(_value);
        
        donationPool -= _value;
        donationsHistory[msg.sender] -= _value;

        emit RefundProcessed(msg.sender, _value, block.timestamp);
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        
        (uint256 _goal, address _fundraiser, uint256 _vestingTime, address _owner) = 
        abi.decode(_initData, (uint256, address, uint256, address));

        goal = _goal;
        fundraiser = _fundraiser;
        vestingTime = _vestingTime;
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    function getInitData(uint256 _goal, address _fundraiser, uint64 _vestingTime, address _owner) external pure returns(bytes memory) {

        return abi.encode(_goal, _fundraiser, _vestingTime, _owner);
    }

    function withdraw() external {
    
    require(msg.sender == fundraiser, OnlyFundraiserAllowed());
    require(address(vestingWallet) != address(0), VestingNotStarted());
    
    vestingWallet.release(payable(fundraiser));

    emit FundsWithdrawnFromVesting(fundraiser, block.timestamp);
    }


    receive() external payable{
        require(poolReached == false, PoolHasReached());
        contribute();
    }

}