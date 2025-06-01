//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IUtilityContract.sol";

contract DeployManager is Ownable{

    constructor() Ownable(msg.sender) {
    
    }

    struct ContractInfo{
        uint256 contractFee;
        bool isActive;
        uint256 registredAt;
    }

    event NewContractAdded(address _contractAddress, uint256 _fee, bool _isActive, uint256 _timestamp);
    event ContractStatusChanged(address _contractAddress, bool _isActive, uint256 _timestamp);
    event FeeHasChanged(address _contractAddress, uint256 _newFee, uint256 _oldFee, uint256 _timestamp);
    event ContractDeployed(address _deployer, address _contract, uint256 _payedFees, uint256 _timestamp);

    error CurrentContractDoesNotActive();
    error NotEnoughtFunds();
    error ContractDoesNotExict();
    error InitializationFailed();

    mapping(address => ContractInfo) public contractsData;
    mapping(address => address[]) public deployedContracts;

    function deploy(address _utilityContract, bytes calldata _initData) external payable returns(address _contract){
        
        ContractInfo memory thisContract = contractsData[_utilityContract];
        require(thisContract.registredAt > 0, ContractDoesNotExict());
        require(thisContract.isActive == true, CurrentContractDoesNotActive());
        require(msg.value >= thisContract.contractFee, NotEnoughtFunds());

        address clone = Clones.clone(_utilityContract);
        bool success = IUtilityContract(clone).initialize(_initData);
        require(success, InitializationFailed());

        payable (owner()).transfer(msg.value);

        deployedContracts[msg.sender].push(clone);

        emit ContractDeployed(msg.sender, clone, msg.value, block.timestamp);

        return clone;

    }

    function addNewContract(address _contractAddress, uint256 _fee, bool _isActive) external onlyOwner {
        contractsData[_contractAddress] = ContractInfo({
            contractFee : _fee,
            isActive : _isActive,
            registredAt : block.timestamp
        });

        emit NewContractAdded(_contractAddress, _fee, _isActive, block.timestamp);
    }

    function deactivateContract(address _contractAddress) external onlyOwner {
        require(contractsData[_contractAddress].registredAt >0, ContractDoesNotExict());
        
        contractsData[_contractAddress].isActive = false;

        emit ContractStatusChanged(_contractAddress, false, block.timestamp);
    }

    function activateContract(address _contractAddress) external onlyOwner {
        require(contractsData[_contractAddress].registredAt >0, ContractDoesNotExict());
        
        contractsData[_contractAddress].isActive = true;

        emit ContractStatusChanged(_contractAddress, true, block.timestamp);
    }

    function setFee(address _contractAddress, uint256 _newFee) external onlyOwner {
        require(contractsData[_contractAddress].registredAt >0, ContractDoesNotExict());
        
        uint256 _oldFee = contractsData[_contractAddress].contractFee;
        contractsData[_contractAddress].contractFee = _newFee;

        emit FeeHasChanged(_contractAddress, _newFee, _oldFee, block.timestamp);
    }
}