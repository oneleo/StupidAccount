// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Network} from "test/util/Network.sol";

import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";

import {StupidAccount} from "src/StupidAccount.sol";
import {StupidPaymaster} from "src/StupidPaymaster.sol";

contract ClaimTokenDeploy is Script {
    IEntryPoint entryPoint;
    StupidAccount stupidAccount;
    StupidPaymaster stupidPaymaster;

    address deployer = vm.rememberKey(vm.envUint("DEPLOYER_PRIVATE_KEY"));
    address entrypointAddress = vm.envAddress("ENTRYPOINT_ADDRESS");

    function run() external {
        entryPoint = IEntryPoint(entrypointAddress);
        uint256 depositValue = 0.0001 ether;
        uint256 stakeValue = 0.1 ether;
        uint32 unstakeDelaySec = 86401;

        vm.startBroadcast(deployer);
        stupidAccount = new StupidAccount(entryPoint);
        stupidPaymaster = new StupidPaymaster(entryPoint);
        stupidPaymaster.deposit{value: depositValue}();
        // Refer:
        // https://docs.alchemy.com/docs/bundler-services#rundler-compatibility
        stupidPaymaster.addStake{value: stakeValue}(unstakeDelaySec);
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
