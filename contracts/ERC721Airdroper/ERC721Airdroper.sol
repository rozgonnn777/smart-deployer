//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Airdroper is IUtilityContract, Ownable{

    constructor() Ownable(msg.sender) {}

    IERC721 public nft;
    address public treasury;
    bool public initialized;

    error AlreadyInitialized();
    error ArraysLengthMissmatch();
    error NeedToApprove();

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        
        (address _tokenAddress, address _treasury, address _owner) = 
        abi.decode(_initData, (address, address, address));

        nft = IERC721(_tokenAddress);
        treasury = _treasury;
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    function getInitData(address _tokenAddress, address _treasury, address _owner) external pure returns(bytes memory) {

        return abi.encode(_tokenAddress, _treasury, _owner);
    }

    function airdrop(address[] calldata receivers, uint256[] calldata id) external onlyOwner {
        
        require (receivers.length == id.length, ArraysLengthMissmatch());
        require (nft.isApprovedForAll(treasury, address(this)) == true, NeedToApprove());
        
        for (uint256 i = 0; i < receivers.length; i++){

            nft.safeTransferFrom(treasury, receivers[i], id[i]); 
        } 
    }
}
