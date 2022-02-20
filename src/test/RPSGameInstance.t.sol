// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {RPSToken} from "../RPSToken.sol";
import {RPSCloneFactory} from "../RPSCloneFactory.sol";
import {RPSGameInstance} from "../RPSGameInstance.sol";

contract TestRPSGameInstance is DSTest {
    Vm internal immutable vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address internal constant PLAYER_A = address(0xBEEF);
    address internal constant PLAYER_B = address(0xCAFE);

    address internal users;
    RPSToken internal token;
    RPSCloneFactory internal factory;
    RPSGameInstance internal gameInstance;

    function setUp() public {
        RPSGameInstance implementation = new RPSGameInstance();
        token = new RPSToken(10);
        factory = new RPSCloneFactory(address(implementation));

        address clonedAddress = factory.createRPSGameInstance(PLAYER_A, address(token));

        gameInstance = RPSGameInstance(clonedAddress);
    }

    /// -----------------------------------------------------
    /// utility functions
    /// -----------------------------------------------------

    function gameTest(
        uint256 gameId,
        address _playerA,
        address _playerB,
        address _winner,
        uint256 _betAmount,
        RPSGameInstance.GameState _state
    ) internal {
        (address playerA, address playerB, address winner, uint256 betAmount, RPSGameInstance.GameState state) = abi
            .decode(gameInstance.getGame(gameId), (address, address, address, uint256, RPSGameInstance.GameState));

        assertEq(playerA, _playerA);
        assertEq(playerB, _playerB);
        assertEq(winner, _winner);
        assertEq(betAmount, _betAmount);
        assertEq(uint256(state), uint256(_state));
    }

    function gameDeposit(
        uint256 gameId,
        address player,
        uint256 betAmount
    ) internal {
        token.transfer(player, uint256(100));

        vm.prank(player);
        token.approve(address(gameInstance), uint256(betAmount));

        vm.prank(player);
        gameInstance.register(gameId);
    }

    function gameSubmit(
        uint256 gameId,
        address player,
        bytes32 moveHash
    ) internal {
        vm.prank(player);

        gameInstance.submitMove(gameId, moveHash);
    }

    function gameReveal(
        uint256 gameId,
        address player,
        uint8 move,
        bytes32 salt
    ) internal {
        vm.prank(player);

        gameInstance.revealMove(gameId, move, salt);
    }

    function gameIncentivize(uint256 gameId, address player) internal {
        vm.prank(player);
        gameInstance.incentivizePlayer(gameId);
    }

    /// -----------------------------------------------------
    /// tests
    /// -----------------------------------------------------

    function testOwner() public {
        assertEq(gameInstance.owner(), PLAYER_A);
    }

    function testDummyGame() public {
        gameTest(0, address(0), address(0), address(0), 0, RPSGameInstance.GameState.Finished);
    }

    function testCreateGame() public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameTest(1, PLAYER_A, PLAYER_B, address(0), uint256(10), RPSGameInstance.GameState.GameCreated);
    }

    function testRegister() public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameDeposit(1, PLAYER_A, uint256(10));

        assertEq(token.balanceOf(PLAYER_A), uint256(90));
        gameTest(1, PLAYER_A, PLAYER_B, address(0), 10, RPSGameInstance.GameState.WaitingForPlayersToBet);

        gameDeposit(1, PLAYER_B, uint256(10));

        assertEq(token.balanceOf(PLAYER_B), uint256(90));
        gameTest(1, PLAYER_A, PLAYER_B, address(0), 10, RPSGameInstance.GameState.WaitingForPlayersToSubmitMove);
    }

    function testSubmitMove(bytes32 salt1, bytes32 salt2) public {
        gameInstance.createGame(PLAYER_B, uint256(10));
        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        gameTest(1, PLAYER_A, PLAYER_B, address(0), 10, RPSGameInstance.GameState.WaitingForPlayersToSubmitMove);

        bytes32 playerBMove = keccak256(abi.encodePacked(uint8(2), salt2));
        gameSubmit(1, PLAYER_B, playerBMove);

        gameTest(1, PLAYER_A, PLAYER_B, address(0), 10, RPSGameInstance.GameState.WaitingForPlayersToReveal);
    }

    function testRevealMoveandFinishGame(bytes32 salt1, bytes32 salt2) public {
        gameInstance.createGame(PLAYER_B, uint256(10));
        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        bytes32 playerBMove = keccak256(abi.encodePacked(uint8(2), salt2));
        gameSubmit(1, PLAYER_B, playerBMove);

        gameReveal(1, PLAYER_A, uint8(1), salt1);
        gameTest(1, PLAYER_A, PLAYER_B, address(0), 10, RPSGameInstance.GameState.WaitingForPlayersToReveal);

        gameReveal(1, PLAYER_B, uint8(2), salt2);
        gameTest(1, PLAYER_A, PLAYER_B, PLAYER_B, 10, RPSGameInstance.GameState.Finished);
    }

    function testWithdrawWinnings(bytes32 salt1, bytes32 salt2) public {
        gameInstance.createGame(PLAYER_B, uint256(10));
        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        bytes32 playerBMove = keccak256(abi.encodePacked(uint8(2), salt2));
        gameSubmit(1, PLAYER_B, playerBMove);

        gameReveal(1, PLAYER_A, uint8(1), salt1);
        gameReveal(1, PLAYER_B, uint8(2), salt2);

        vm.prank(PLAYER_B);
        gameInstance.withdrawWinnings(1);
        assertEq(token.balanceOf(PLAYER_B), uint256(110));

        gameTest(1, PLAYER_A, PLAYER_B, PLAYER_B, 10, RPSGameInstance.GameState.Withdrawn);
    }

    function testWithdrawBeforeGameStarts() public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        vm.prank(PLAYER_A);
        gameInstance.withdrawBeforeGameStarts(1);

        assertEq(token.balanceOf(PLAYER_A), uint256(100));
        assertEq(token.balanceOf(PLAYER_B), uint256(100));

        gameTest(1, PLAYER_A, PLAYER_B, address(0), 10, RPSGameInstance.GameState.Withdrawn);
    }

    function testRematchWithWinnings(bytes32 salt1, bytes32 salt2) public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        bytes32 playerBMove = keccak256(abi.encodePacked(uint8(2), salt2));
        gameSubmit(1, PLAYER_B, playerBMove);

        gameReveal(1, PLAYER_A, uint8(1), salt1);
        gameReveal(1, PLAYER_B, uint8(2), salt2);

        vm.prank(PLAYER_B);
        gameInstance.rematchWithWinnings(1);

        gameTest(1, PLAYER_A, PLAYER_B, address(0), 20, RPSGameInstance.GameState.WaitingForPlayersToBet);

        gameDeposit(1, PLAYER_A, uint256(20));
    }

    function testRematch(bytes32 salt1, bytes32 salt2) public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        bytes32 playerBMove = keccak256(abi.encodePacked(uint8(2), salt2));
        gameSubmit(1, PLAYER_B, playerBMove);

        gameReveal(1, PLAYER_A, uint8(1), salt1);
        gameReveal(1, PLAYER_B, uint8(2), salt2);

        vm.prank(PLAYER_A);
        gameInstance.requestRematch(1);

        vm.prank(PLAYER_B);
        gameInstance.requestRematch(1);

        gameTest(1, PLAYER_A, PLAYER_B, PLAYER_B, 10, RPSGameInstance.GameState.WaitingForPlayersToBet);
    }

    function testSubmitMoveIncentivize(bytes32 salt1) public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        gameIncentivize(1, PLAYER_A);

        vm.warp(block.timestamp + 2 hours);

        gameIncentivize(1, PLAYER_A);

        gameTest(1, PLAYER_A, PLAYER_B, PLAYER_A, 10, RPSGameInstance.GameState.Finished);
    }

    function testFailSubmitMoveIncentivize(bytes32 salt1, bytes32 salt2) public {
        gameInstance.createGame(PLAYER_B, uint256(10));

        gameDeposit(1, PLAYER_A, uint256(10));
        gameDeposit(1, PLAYER_B, uint256(10));

        bytes32 playerAMove = keccak256(abi.encodePacked(uint8(1), salt1));
        gameSubmit(1, PLAYER_A, playerAMove);

        vm.prank(PLAYER_A);
        gameInstance.incentivizePlayer(1);

        vm.warp(block.timestamp + 2 hours);

        bytes32 playerBMove = keccak256(abi.encodePacked(uint8(2), salt2));
        gameSubmit(1, PLAYER_B, playerBMove);
    }
}
