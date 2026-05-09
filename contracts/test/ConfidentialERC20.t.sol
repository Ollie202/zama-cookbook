// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FhevmTest} from "forge-fhevm/FhevmTest.sol";
import {ConfidentialERC20} from "../src/ConfidentialERC20.sol";
import {externalEuint64, euint64} from "encrypted-types/EncryptedTypes.sol";

contract ConfidentialERC20Test is FhevmTest {
    ConfidentialERC20 token;
    uint256 internal constant ALICE_PK = 0xA11CE;
    uint256 internal constant BOB_PK   = 0xB0B;
    address alice;
    address bob;

    function setUp() public override {
        super.setUp();
        token = new ConfidentialERC20("Confidential USD", "cUSD");
        alice = vm.addr(ALICE_PK);
        bob   = vm.addr(BOB_PK);
    }

    function _decryptBal(address user, uint256 pk) internal returns (uint256) {
        bytes memory sig = signUserDecrypt(pk, address(token));
        return userDecrypt(euint64.unwrap(token.balanceOf(user)), user, address(token), sig);
    }

    function test_MintAndDecryptBalance() public {
        (externalEuint64 enc, bytes memory proof) = encryptUint64(1000, address(this), address(token));
        token.mint(alice, enc, proof);
        assertEq(_decryptBal(alice, ALICE_PK), 1000);
    }

    function test_TransferFullAmount() public {
        (externalEuint64 m, bytes memory mp) = encryptUint64(1000, address(this), address(token));
        token.mint(alice, m, mp);

        (externalEuint64 t, bytes memory tp) = encryptUint64(250, alice, address(token));
        vm.prank(alice);
        token.transfer(bob, t, tp);

        assertEq(_decryptBal(alice, ALICE_PK), 750);
        assertEq(_decryptBal(bob,   BOB_PK),   250);
    }

    function test_ClampsToZeroOnOverdraft() public {
        // Alice has 0; tries to send 100. Contract silent-clamps to 0 transfer.
        (externalEuint64 t, bytes memory tp) = encryptUint64(100, alice, address(token));
        vm.prank(alice);
        token.transfer(bob, t, tp);

        assertEq(_decryptBal(bob, BOB_PK), 0);
    }
}
