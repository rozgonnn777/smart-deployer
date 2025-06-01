//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC1155Airdroper is IUtilityContract, Ownable{

    constructor() Ownable(msg.sender) {}

    IERC1155 public tokens;
    address public treasury;
    bool public initialized;

    error AlreadyInitialized();
    error ArraysLengthMissmatch();
    error NeedToUpproveTokens();

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        
        (address _tokenAddress, address _treasury, address _owner) = 
        abi.decode(_initData, (address, address, address));

        tokens = IERC1155(_tokenAddress);
        treasury = _treasury;
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    function getInitData(address _tokenAddress, address _treasury, address _owner) external pure returns(bytes memory) {

        return abi.encode(_tokenAddress, _treasury, _owner);
    }

    function airdrop(address[] calldata receivers, uint256[] calldata amounts, uint256[] calldata tokenId) external onlyOwner {
        
        require (receivers.length == amounts.length && tokenId.length == receivers.length, ArraysLengthMissmatch());
        require (tokens.isApprovedForAll(treasury, address(this)), NeedToUpproveTokens());
        
        for (uint256 i = 0; i < receivers.length; i++){

         tokens.safeTransferFrom(treasury, receivers[i], tokenId[i], amounts[i], "");
        } 
    }
}
