// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { SablierLockup } from "../src/SablierLockup.sol";
import { Lockup, LockupLinear, Broker } from "../src/types/DataTypes.sol";

contract CreateDuckLockup is Script {
    // Hardcoded addresses
    address constant DUCK_TOKEN = 0xdA65892eA771d3268610337E9964D916028B7dAD;
    address constant SABLIER_LOCKUP = 0x4051Ca516a3f8F0c1Bb1D677413b5a883d6c23ab; // TODO: Replace with actual deployed address

    // Lockup parameters
    uint128 constant LOCKUP_AMOUNT = 100e9; // 100 DUCK tokens (assuming 9 decimals)
    uint40 constant LOCKUP_DURATION = 7 days; // 1 week

    function run() public {
        // Get the creator's address from private key
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address creator = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        // Get contract instances
        IERC20 duckToken = IERC20(DUCK_TOKEN);
        SablierLockup sablierLockup = SablierLockup(SABLIER_LOCKUP);

        console2.log("=== DUCK Token Lockup Setup ===");
        console2.log("Creator/Recipient:", creator);
        console2.log("DUCK Token:", DUCK_TOKEN);
        console2.log("Sablier Lockup:", SABLIER_LOCKUP);
        console2.log("Lockup Amount:", LOCKUP_AMOUNT / 1e9, "DUCK");
        console2.log("Lockup Duration:", LOCKUP_DURATION, "seconds");

        // Check DUCK token balance
        uint256 balance = duckToken.balanceOf(creator);
        console2.log("Current DUCK balance:", balance / 1e9, "DUCK");

        require(balance >= LOCKUP_AMOUNT, "Insufficient DUCK balance");

        // Check and approve DUCK tokens for SablierLockup
        uint256 allowance = duckToken.allowance(creator, SABLIER_LOCKUP);
        console2.log("Current allowance:", allowance / 1e9, "DUCK");

        if (allowance < LOCKUP_AMOUNT) {
            console2.log("Approving DUCK tokens...");
            duckToken.approve(SABLIER_LOCKUP, LOCKUP_AMOUNT);
            console2.log("Approval successful");
        }

        // Prepare lockup parameters
        Lockup.CreateWithDurations memory params = Lockup.CreateWithDurations({
            sender: creator,
            recipient: creator, // Same as creator per requirements
            totalAmount: LOCKUP_AMOUNT,
            token: duckToken,
            transferable: true,
            shape: "Linear Vesting",
            broker: Broker({
                account: address(0), // No broker
                fee: UD60x18.wrap(0) // No broker fee
            })
        });

        // Unlock amounts (no cliff, all tokens unlock linearly)
        LockupLinear.UnlockAmounts memory unlockAmounts = LockupLinear.UnlockAmounts({
            start: 0, // No tokens unlocked at start
            cliff: 0  // No cliff unlock
        });

        // Durations (no cliff, 1 week total)
        LockupLinear.Durations memory durations = LockupLinear.Durations({
            cliff: 0,           // No cliff period
            total: LOCKUP_DURATION // 1 week total duration
        });

        console2.log("Creating linear lockup stream...");

        // Create the lockup stream
        uint256 streamId = sablierLockup.createWithDurationsLL(
            params,
            unlockAmounts,
            durations
        );

        console2.log("=== Lockup Created Successfully ===");
        console2.log("Stream ID:", streamId);
        console2.log("Start time:", block.timestamp);
        console2.log("End time:", block.timestamp + LOCKUP_DURATION);
        console2.log("Tokens will vest linearly over", LOCKUP_DURATION / 86400, "days");

        // Display some stream info
        console2.log("=== Stream Information ===");
        console2.log("Deposited amount:", sablierLockup.getDepositedAmount(streamId) / 1e9, "DUCK");

        vm.stopBroadcast();
    }
}