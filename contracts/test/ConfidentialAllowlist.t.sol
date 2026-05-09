// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FhevmTest} from "forge-fhevm/FhevmTest.sol";
import {ConfidentialAllowlist} from "../src/ConfidentialAllowlist.sol";
import {externalEuint64, euint64} from "encrypted-types/EncryptedTypes.sol";

contract ConfidentialAllowlistTest is FhevmTest {
    ConfidentialAllowlist gate;
    uint256 internal constant ALICE_PK = 0xA11CE;
    uint256 internal constant BOB_PK   = 0xB0B;
    address alice;
    address bob;

    function setUp() public override {
        super.setUp();
        gate = new ConfidentialAllowlist();
        alice = vm.addr(ALICE_PK);
        bob   = vm.addr(BOB_PK);
    }

    function _callGated(address who, uint64 amount) internal {
        (externalEuint64 enc, bytes memory proof) = encryptUint64(amount, who, address(gate));
        vm.prank(who);
        gate.gatedIncrement(enc, proof);
    }

    function _decryptCounter(address who, uint256 pk) internal returns (uint256) {
        bytes memory sig = signUserDecrypt(pk, address(gate));
        return userDecrypt(euint64.unwrap(gate.counter(who)), who, address(gate), sig);
    }

    function test_AdmitMemberCanIncrement() public {
        gate.grant(alice);
        _callGated(alice, 7);
        assertEq(_decryptCounter(alice, ALICE_PK), 7);
    }

    function test_NonMemberSilentlyNoOps() public {
        // bob was never granted
        _callGated(bob, 99);
        assertEq(_decryptCounter(bob, BOB_PK), 0);
    }

    function test_OnlyAdminCanGrantOrRevoke() public {
        vm.prank(alice);
        vm.expectRevert(bytes("not admin"));
        gate.grant(alice);

        vm.prank(alice);
        vm.expectRevert(bytes("not admin"));
        gate.revoke(alice);
    }
}
