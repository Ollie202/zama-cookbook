// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FhevmTest} from "forge-fhevm/FhevmTest.sol";
import {PrivateVote} from "../src/PrivateVote.sol";
import {externalEuint8, euint32} from "encrypted-types/EncryptedTypes.sol";

contract PrivateVoteTest is FhevmTest {
    PrivateVote vote;
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address carol = address(0xCA001);

    function setUp() public override {
        super.setUp();
        vote = new PrivateVote(3, 3600); // 3 options, 1h
        address[] memory voters = new address[](3);
        voters[0] = alice; voters[1] = bob; voters[2] = carol;
        vote.setEligible(voters);
    }

    function _vote(address who, uint8 choice) internal {
        (externalEuint8 enc, bytes memory proof) = encryptUint8(choice, who, address(vote));
        vm.prank(who);
        vote.vote(enc, proof);
    }

    function test_RevealAfterDeadlineExposesTallies() public {
        _vote(alice, 0);
        _vote(bob,   1);
        _vote(carol, 1);

        vm.warp(block.timestamp + 3601);
        vote.reveal();
        assertTrue(vote.revealed());

        bytes32[] memory handles = new bytes32[](3);
        handles[0] = euint32.unwrap(vote.tallyOf(0));
        handles[1] = euint32.unwrap(vote.tallyOf(1));
        handles[2] = euint32.unwrap(vote.tallyOf(2));
        (uint256[] memory cts, ) = publicDecrypt(handles);

        assertEq(cts[0], 1);
        assertEq(cts[1], 2);
        assertEq(cts[2], 0);
    }

    function test_DoubleVoteReverts() public {
        _vote(alice, 0);
        (externalEuint8 enc, bytes memory proof) = encryptUint8(1, alice, address(vote));
        vm.prank(alice);
        vm.expectRevert(bytes("already voted"));
        vote.vote(enc, proof);
    }
}
