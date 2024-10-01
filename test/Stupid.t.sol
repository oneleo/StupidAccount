// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";

import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@aa/interfaces/PackedUserOperation.sol";

import {StupidAccount, PaymasterMode} from "src/StupidAccount.sol";
import {StupidPaymaster} from "src/StupidPaymaster.sol";

contract ForkTest is Test {
    // Access variables from .env file via vm.envString("varname")
    string BASE_SEPOLIA_NODE_RPC_URL = vm.envString("BASE_SEPOLIA_NODE_RPC_URL");
    address ENTRYPOINT_ADDRESS = vm.envAddress("ENTRYPOINT_ADDRESS");

    // the identifiers of the forks
    uint256 baseSepoliaFork;
    address paymasterOwner;
    address bundler;

    function setUp() public {
        baseSepoliaFork = vm.createFork(BASE_SEPOLIA_NODE_RPC_URL);
        paymasterOwner = makeAddr("paymasterOwner");
        bundler = makeAddr("bundler");
    }

    // select a specific fork
    function testHandleOps() public {
        // select the fork
        vm.selectFork(baseSepoliaFork);
        assertEq(vm.activeFork(), baseSepoliaFork);

        // set `block.number` of a fork
        uint256 forkBlockNumber = 15_555_555;
        vm.rollFork(forkBlockNumber);
        assertEq(block.number, forkBlockNumber);

        // +++

        IEntryPoint entrypoint = IEntryPoint(ENTRYPOINT_ADDRESS);

        uint256 paymasterDepositAmount = 1 ether;

        vm.deal(paymasterOwner, 1000 ether);
        vm.startPrank(paymasterOwner);
        StupidPaymaster stupidPaymaster = new StupidPaymaster(entrypoint);
        entrypoint.depositTo{value: paymasterDepositAmount}(address(stupidPaymaster));
        vm.stopPrank();

        assertEq(entrypoint.balanceOf(address(stupidPaymaster)), paymasterDepositAmount);

        // +++

        StupidAccount stupidAccount = new StupidAccount(entrypoint);

        PackedUserOperation[] memory packedUserOperations = new PackedUserOperation[](1);
        packedUserOperations[0] =
            stupidAccount.buildStupidUserOp(address(stupidPaymaster), PaymasterMode.ChargeInPostOp);

        vm.startPrank(bundler);
        entrypoint.handleOps(packedUserOperations, payable(bundler));
        vm.stopPrank();
    }
}
