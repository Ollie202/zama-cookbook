// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {FhevmTest} from "forge-fhevm/FhevmTest.sol";
import {SealedBidAuction} from "../src/SealedBidAuction.sol";
import {externalEuint64, euint64, eaddress} from "encrypted-types/EncryptedTypes.sol";

contract SealedBidAuctionTest is FhevmTest {
    SealedBidAuction auction;
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address carol = address(0xCA001);

    function setUp() public override {
        super.setUp();
        auction = new SealedBidAuction("Vintage 1985 Macintosh", 3600);
    }

    function _bid(address bidder, uint64 amount) internal {
        (externalEuint64 enc, bytes memory proof) = encryptUint64(amount, bidder, address(auction));
        vm.prank(bidder);
        auction.bid(enc, proof);
    }

    function test_HighestBidPubliclyDecryptableOnSettle() public {
        _bid(alice, 100);
        _bid(bob,   250);
        _bid(carol, 175);

        vm.warp(block.timestamp + 3601);
        auction.settle();
        assertTrue(auction.settled());

        bytes32[] memory handles = new bytes32[](2);
        handles[0] = euint64.unwrap(auction.highestBid());
        handles[1] = eaddress.unwrap(auction.highestBidder());
        (uint256[] memory cts, ) = publicDecrypt(handles);

        assertEq(cts[0], 250);
        assertEq(address(uint160(cts[1])), bob);
    }

    function test_RejectsBidsAfterDeadline() public {
        vm.warp(block.timestamp + 3601);
        (externalEuint64 enc, bytes memory proof) = encryptUint64(1, alice, address(auction));
        vm.prank(alice);
        vm.expectRevert(bytes("auction closed"));
        auction.bid(enc, proof);
    }

    function test_CannotSettleBeforeDeadline() public {
        _bid(alice, 50);
        vm.expectRevert(bytes("auction running"));
        auction.settle();
    }
}
