// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {RPSToken} from "../RPSToken.sol";
import {RPSCloneFactory} from "../RPSCloneFactory.sol";
import {RPSGameInstance} from "../RPSGameInstance.sol";

contract TestRPSCloneFactory is DSTest {
    RPSCloneFactory internal factory;
    address internal constant PLAYER_A = address(0xBEEF);
    RPSToken internal token;

    function setUp() public {
        RPSGameInstance implementation = new RPSGameInstance();
        token = new RPSToken(10);
        factory = new RPSCloneFactory(address(implementation));
    }

    function testCreateGame() public {
        address clonedAddress = factory.createRPSGameInstance(PLAYER_A, address(token));

        assertTrue(clonedAddress != address(0));
        assertEq(clonedAddress, factory.getCloneAddress(PLAYER_A));
    }
}
