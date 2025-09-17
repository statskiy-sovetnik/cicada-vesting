// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { PRBMathUtils } from "@prb/math/test/utils/Utils.sol";
import { CommonBase } from "forge-std/src/Base.sol";

import { LockupTranched } from "../../src/types/DataTypes.sol";

abstract contract Utils is CommonBase, PRBMathUtils {
    /// @dev Bounds a `uint128` number.
    function boundUint128(uint128 x, uint128 min, uint128 max) internal pure returns (uint128) {
        return uint128(_bound(uint256(x), uint256(min), uint256(max)));
    }

    /// @dev Bounds a `uint40` number.
    function boundUint40(uint40 x, uint40 min, uint40 max) internal pure returns (uint40) {
        return uint40(_bound(uint256(x), uint256(min), uint256(max)));
    }

    /// @dev Retrieves the current block timestamp as an `uint40`.
    function getBlockTimestamp() internal view returns (uint40) {
        return uint40(block.timestamp);
    }


    /// @dev Turns the tranches with durations into canonical tranches, which have timestamps.
    function getTranchesWithTimestamps(LockupTranched.TrancheWithDuration[] memory tranches)
        internal
        view
        returns (LockupTranched.Tranche[] memory tranchesWithTimestamps)
    {
        unchecked {
            tranchesWithTimestamps = new LockupTranched.Tranche[](tranches.length);
            tranchesWithTimestamps[0] = LockupTranched.Tranche({
                amount: tranches[0].amount,
                timestamp: getBlockTimestamp() + tranches[0].duration
            });
            for (uint256 i = 1; i < tranches.length; ++i) {
                tranchesWithTimestamps[i] = LockupTranched.Tranche({
                    amount: tranches[i].amount,
                    timestamp: tranchesWithTimestamps[i - 1].timestamp + tranches[i].duration
                });
            }
        }
    }

    /// @dev Checks if the Foundry profile is "benchmark".
    function isBenchmarkProfile() internal view returns (bool) {
        string memory profile = vm.envOr({ name: "FOUNDRY_PROFILE", defaultValue: string("default") });
        return Strings.equal(profile, "benchmark");
    }

    /// @dev Checks if the Foundry profile is "test-optimized".
    function isTestOptimizedProfile() internal view returns (bool) {
        string memory profile = vm.envOr({ name: "FOUNDRY_PROFILE", defaultValue: string("default") });
        return Strings.equal(profile, "test-optimized");
    }

    /// @dev Returns the largest of the provided `uint40` numbers.
    function maxOfTwo(uint40 a, uint40 b) internal pure returns (uint40) {
        uint40 max = a;
        if (b > max) {
            max = b;
        }
        return max;
    }

    /// @dev Stops the active prank and sets a new one.
    function resetPrank(address msgSender) internal {
        vm.stopPrank();
        vm.startPrank(msgSender);
    }
}
