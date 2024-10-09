// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";

import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@aa/interfaces/PackedUserOperation.sol";

import {StupidAccount} from "src/StupidAccount.sol";
import {StupidPaymaster, PaymasterMode} from "src/StupidPaymaster.sol";

contract ForkTest is Test {
    // Access variables from .env file via vm.envString("varname")
    string BASE_SEPOLIA_NODE_RPC_URL = vm.envString("BASE_SEPOLIA_NODE_RPC_URL");
    address ENTRYPOINT_ADDRESS = vm.envAddress("ENTRYPOINT_ADDRESS");

    // the identifiers of the forks
    uint256 baseSepoliaFork;
    address paymasterOwner;
    address bundler;

    IEntryPoint entrypoint;
    StupidAccount stupidAccount;
    StupidPaymaster stupidPaymaster;

    function setUp() public {
        baseSepoliaFork = vm.createFork(BASE_SEPOLIA_NODE_RPC_URL);
        paymasterOwner = makeAddr("paymasterOwner");
        bundler = makeAddr("bundler");

        // select the fork
        vm.selectFork(baseSepoliaFork);
        assertEq(vm.activeFork(), baseSepoliaFork);

        // set `block.number` of a fork
        uint256 forkBlockNumber = 15_555_555;
        vm.rollFork(forkBlockNumber);
        assertEq(block.number, forkBlockNumber);

        entrypoint = IEntryPoint(ENTRYPOINT_ADDRESS);

        uint256 paymasterDepositAmount = 1 ether;

        vm.deal(paymasterOwner, 1000 ether);
        vm.startPrank(paymasterOwner);
        stupidPaymaster = new StupidPaymaster(entrypoint);
        entrypoint.depositTo{value: paymasterDepositAmount}(address(stupidPaymaster));
        vm.stopPrank();

        assertEq(entrypoint.balanceOf(address(stupidPaymaster)), paymasterDepositAmount);

        stupidAccount = new StupidAccount(entrypoint);
    }

    function testHandleOpsForChargeMode() public {
        PackedUserOperation[] memory packedUserOperations = new PackedUserOperation[](1);

        packedUserOperations[0] =
            stupidAccount.buildStupidUserOp(address(stupidPaymaster), PaymasterMode.ChargeInPostOp);

        vm.expectEmit(false, true, true, false, address(stupidPaymaster));
        emit StupidPaymaster.UserOpProcessed(
            bytes32(uint256(999)), // Unknown userOpHash
            address(stupidAccount),
            bytes32(uint256(1)),
            PaymasterMode.ChargeInPostOp,
            999, // Unknown actualGasCost
            address(1),
            1,
            address(1),
            false
        );

        vm.startPrank(bundler);
        entrypoint.handleOps(packedUserOperations, payable(bundler));
        vm.stopPrank();
    }

    function testHandleOpsForSponsorMode() public {
        PackedUserOperation[] memory packedUserOperations = new PackedUserOperation[](1);

        packedUserOperations[0] = stupidAccount.buildStupidUserOp(address(stupidPaymaster), PaymasterMode.Sponsor);

        vm.expectEmit(false, true, true, false, address(stupidPaymaster));
        emit StupidPaymaster.UserOpProcessed(
            bytes32(uint256(999)), // Unknown userOpHash
            address(stupidAccount),
            bytes32(uint256(0)),
            PaymasterMode.ChargeInPostOp,
            999, // Unknown actualGasCost
            address(0),
            0,
            address(0),
            false
        );

        vm.startPrank(bundler);
        entrypoint.handleOps(packedUserOperations, payable(bundler));
        vm.stopPrank();
    }
}
