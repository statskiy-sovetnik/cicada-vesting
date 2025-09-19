// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { console2 } from "forge-std/src/console2.sol";
import { TestToken } from "../src/TestToken.sol";
import { Script } from "forge-std/src/Script.sol";

contract DeployTestToken is Script {
    function run() public {
        vm.startBroadcast();

        TestToken token = new TestToken();

        console2.log("TestToken deployed at:", address(token));
        console2.log("Deployed at block:", token.getDeployedBlock());
        console2.log("Initial supply:", token.totalSupply());

        vm.stopBroadcast();
    }
}