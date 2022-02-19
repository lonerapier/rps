// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {RPSGameInstance} from "./RPSGameInstance.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract RPSCloneFactory {
    address private immutable rpsImplementationAddress;

    event GameCreated(address indexed creator, address indexed _contractAddress, address indexed _tokenAddress);

    mapping(address => address) private rpsCloneAddresses;

    constructor(address _address) {
        rpsImplementationAddress = _address;
    }

    function createRPSGameInstance(address _tokenAddress) external returns (address) {
        require(rpsCloneAddresses[msg.sender] == address(0), "Only one RPS game instance");

        address cloneAddress = Clones.clone(rpsImplementationAddress);
        RPSGameInstance(cloneAddress).initialize(msg.sender, _tokenAddress);

        emit GameCreated(msg.sender, cloneAddress, _tokenAddress);
        return cloneAddress;
    }

    function getImplementationAddress() external view returns (address) {
        return rpsImplementationAddress;
    }

    function getCloneAddress(address _creator) external view returns (address) {
        return rpsCloneAddresses[_creator];
    }
}
