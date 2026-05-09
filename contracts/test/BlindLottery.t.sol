// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FhevmTest} from "forge-fhevm/FhevmTest.sol";
import {BlindLottery} from "../src/BlindLottery.sol";
import {euint32, eaddress} from "encrypted-types/EncryptedTypes.sol";

contract BlindLotteryTest is FhevmTest {
    BlindLottery lot;
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address carol = address(0xCA001);

    function setUp() public override {
        super.setUp();
        lot = new BlindLottery(3600, 10);
    }

    function test_OneEntryPerAddress() public {
        vm.prank(alice);
        lot.enter();
        vm.prank(alice);
        vm.expectRevert(bytes("already entered"));
        lot.enter();
        assertEq(lot.entrantCount(), 1);
    }

    function test_DrawSelectsValidEntrant() public {
        address[3] memory players = [alice, bob, carol];
        for (uint256 i = 0; i < players.length; i++) {
            vm.prank(players[i]);
            lot.enter();
        }

        vm.warp(block.timestamp + 3601);
        lot.draw();
        assertTrue(lot.drawn());

        bytes32[] memory handles = new bytes32[](2);
        handles[0] = euint32.unwrap(lot.winnerIndex());
        handles[1] = eaddress.unwrap(lot.winnerAddress());
        (uint256[] memory cts, ) = publicDecrypt(handles);

        uint256 idx = cts[0];
        assertTrue(idx < players.length);
        assertEq(address(uint160(cts[1])), players[idx]);
    }
}
