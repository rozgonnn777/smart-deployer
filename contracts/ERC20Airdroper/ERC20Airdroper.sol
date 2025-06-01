//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Airdroper is IUtilityContract, Ownable{

    constructor() Ownable(msg.sender) {}

    address public deployer;
    IERC20 public tokens;
    uint256 public amount;
    address public treasury;
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

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        
        (address _tokenAddress, uint256 _airdropAmount, address _treasury, address _owner) = 
        abi.decode(_initData, (address, uint256, address, address));

        tokens = IERC20(_tokenAddress);
        amount = _airdropAmount;
        treasury = _treasury;
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    function getInitData(address _tokenAddress, uint256 _airdropAmount, address _treasury, address _owner) external pure returns(bytes memory) {

        return abi.encode(_tokenAddress, _airdropAmount, _treasury, _owner);
    }

    function airdrop(address[] calldata receivers,uint256[] calldata amounts) external onlyOwner {
        
        require (receivers.length == amounts.length, ArraysLengthMissmatch());
        require (tokens.allowance(treasury, address(this)) >= amount, NotEnoughtUpprovedTokens());
        
        for (uint256 i = 0; i < receivers.length; i++){

            require (tokens.transferFrom(treasury, receivers[i], amounts[i]), TransferToAdressFailed()); 
        } 
    }
}
