//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../UtilityContract/AbstractUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC20Airdroper - Utility contract for ERC1155 tokens distributions (airdrop).
/// @author rozghon7.
/// @notice This contract provides a distribution functionality for ERC1155 tokens.
contract ERC1155Airdroper is AbstractUtilityContract, Ownable {
    /// @notice Initializes Ownable with deployer.
    constructor() payable Ownable(msg.sender) {}

    /// @notice The ERC1155 token contract from which tokens will be distributed.
    IERC1155 public tokens;
    /// @notice Address which holding tokens for distribution.
    address public treasury;
    /// @notice Transfer limit of token transfers per airdrop call.
    uint256 public constant MAX_AIRDROP_ITERATIONS = 77;

    /// @dev Reverts if arrays length is different.
    error ArraysLengthMissmatch();
    /// @dev Reverts if tresuary doesn't approve tokens for ERC1155Airdropper.
    error NeedToApproveTokens();
    /// @dev Reverts if iterations quantity more than MAX_AIRDROP_ITTERATIONS.
    error IterationsQuantityMissmatch();

    /// @inheritdoc IUtilityContract
    function initialize(bytes memory _initData) external override notInitialized returns (bool) {
        (address _deployManager, address _tokenAddress, address _treasury, address _owner) =
            abi.decode(_initData, (address, address, address, address));

        setDeployManager(_deployManager);
        tokens = IERC1155(_tokenAddress);
        treasury = _treasury;
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    /// @notice Helper to encode constructor-style init data.
    /// @param _deployManager Address of the DeployManager.
    /// @param _tokenAddress Address of ERC1155 token contract.
    /// @param _treasury Address holding the tokens.
    /// @param _owner New owner of the contract.
    /// @return Encoded initialization bytes.
    function getInitData(address _deployManager, address _tokenAddress, address _treasury, address _owner)
        external
        pure
        returns (bytes memory)
    {
        return abi.encode(_deployManager, _tokenAddress, _treasury, _owner);
    }

    /// @notice Distributes tokens to recipients from treasury address.
    /// @param receivers Users addresses to receive tokens.
    /// @param amounts Amount of tokens distribution for every receiver.
    /// @param tokenId The tokens IDs for distribution.
    function airdrop(address[] calldata receivers, uint256[] calldata amounts, uint256[] calldata tokenId)
        external
        onlyOwner
    {
        require(tokenId.length <= MAX_AIRDROP_ITERATIONS, IterationsQuantityMissmatch());
        require(receivers.length == tokenId.length, ArraysLengthMissmatch());
        require(tokenId.length == amounts.length, ArraysLengthMissmatch());
        require(tokens.isApprovedForAll(treasury, address(this)), NeedToApproveTokens());

        address treasuryAddress = treasury;

        for (uint256 i = 0; i < receivers.length;) {
            tokens.safeTransferFrom(treasuryAddress, receivers[i], tokenId[i], amounts[i], "");
            unchecked {
                ++i;
            }
        }
    }
}
