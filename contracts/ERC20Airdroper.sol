//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IUtilityContract.sol";

contract ERC20Airdroper is IUtilityContract{

    address public deployer;
    IERC20 public tokens;
    uint256 public amount;
    bool public initialized;

    error AlreadyInitialized();
    error ArraysLengthMissmatch();
    error NotEnoughtUpprovedTokens();
    error TransferToAdressFailed();
    error OnlyDeployerAllowed();

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, OnlyDeployerAllowed());
        _;
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        
        (address _tokenAddress, uint256 _airdropAmount) = 
        abi.decode(_initData, (address, uint256));

        tokens = IERC20(_tokenAddress);
        amount = _airdropAmount;
        deployer = msg.sender;

        initialized = true;
        return true;
    }

    function getInitData(address _tokenAddress, uint256 _airdropAmount) external pure returns(bytes memory) {

        return abi.encode(_tokenAddress, _airdropAmount);
    }

    function airdrop(address[] calldata receivers,
    uint256[] calldata amounts) external onlyDeployer {
        
        require (receivers.length == amounts.length, ArraysLengthMissmatch());
        require (tokens.allowance(msg.sender, address(this)) >= amount, NotEnoughtUpprovedTokens());
        
        for (uint256 i = 0; i < receivers.length; i++){

            require (tokens.transferFrom(msg.sender, receivers[i], amounts[i]), TransferToAdressFailed()); 
        } 
    }
}
