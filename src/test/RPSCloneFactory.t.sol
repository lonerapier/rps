// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {RPSCloneFactory} from "../RPSCloneFactory.sol";
import {RPSGameInstance} from "../RPSGameInstance.sol";

contract TestRPSCloneFactory is DSTest {
    RPSCloneFactory internal factory;
    address internal player = address(0xBEEF);
    address internal tokenAddress = 0x5FbDB2315678afecb367f032d93F642f64180aa3;

    function setUp() public {
        factory = new RPSCloneFactory(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    }

    function testCreateGame() public {
        address cloneAddress = factory.createRPSGameInstance(player, tokenAddress);

        assertTrue(cloneAddress != address(0));
        assertEq(cloneAddress, factory.getCloneAddress(player));
    }
}
