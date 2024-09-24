// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Network} from "test/util/Network.sol";

import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";

import {StupidAccount} from "src/StupidAccount.sol";
import {StupidPaymaster} from "src/StupidPaymaster.sol";

contract ClaimTokenDeploy is Script {
    StupidAccount stupidAccount;
    StupidPaymaster stupidPaymaster;

    address deployer = vm.rememberKey(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    address entrypointAddress = vm.envAddress("ENTRYPOINT_ADDRESS");

    function run() external {
        vm.startBroadcast(deployer);
        stupidAccount = new StupidAccount(IEntryPoint(entrypointAddress));
        stupidPaymaster = new StupidPaymaster(IEntryPoint(entrypointAddress));
        vm.stopBroadcast();

        string memory currentNetwork = Network.getNetworkName(block.chainid);
        string memory outputFilePath = "script/output/Address.json";
        string memory jsonData = string.concat(
            '{"',
            currentNetwork,
            '":{"stupidAccount":"',
            vm.toString(address(stupidAccount)),
            '","stupidPaymaster":"',
            vm.toString(address(stupidPaymaster)),
            '"}}'
        );
        vm.writeJson(jsonData, outputFilePath);

        console.log("stupidAccount:");
        console.logAddress(address(stupidAccount));
        console.log("stupidPaymaster:");
        console.logAddress(address(stupidPaymaster));
    }
}
