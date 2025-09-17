// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { PRBMathCastingUint128 as CastingUint128 } from "@prb/math/src/casting/Uint128.sol";
import { UD60x18, ud, uUNIT } from "@prb/math/src/UD60x18.sol";

import { Lockup, LockupTranched } from "../../src/types/DataTypes.sol";

import { Constants } from "./Constants.sol";
import { Utils } from "./Utils.sol";

abstract contract Fuzzers is Constants, Utils {
    using CastingUint128 for uint128;


    /*//////////////////////////////////////////////////////////////////////////
                                  LOCKUP-TRANCHED
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Fuzzes the tranche durations.
    function fuzzTrancheDurations(LockupTranched.TrancheWithDuration[] memory tranches) internal view {
        unchecked {
            // Precompute the first tranche duration.
            tranches[0].duration = uint40(_bound(tranches[0].duration, 1, 100));

            // Bound the durations so that none is zero and the calculations don't overflow.
            uint256 durationCount = tranches.length;
            uint40 maxDuration = (MAX_UNIX_TIMESTAMP - getBlockTimestamp()) / uint40(durationCount);
            for (uint256 i = 1; i < durationCount; ++i) {
                tranches[i].duration = boundUint40(tranches[i].duration, 1, maxDuration);
            }
        }
    }

    /// @dev Fuzzes the tranche timestamps.
    function fuzzTrancheTimestamps(LockupTranched.Tranche[] memory tranches, uint40 startTime) internal pure {
        // Return here if there's only one tranche to not run into division by zero.
        uint40 trancheCount = uint40(tranches.length);
        if (trancheCount == 1) {
            tranches[0].timestamp = startTime + 2 days;
            return;
        }

        // The first timestamps is precomputed to avoid an underflow in the first loop iteration. We have to
        // add 1 because the first timestamp must be greater than the start time.
        tranches[0].timestamp = startTime + 1 seconds;

        // Fuzz the timestamps while preserving their order in the array. For each timestamp, set its initial guess
        // as the sum of the starting timestamp and the step size multiplied by the current index. This ensures that
        // the initial guesses are evenly spaced. Next, we bound the timestamp within a range of half the step size
        // around the initial guess.
        uint256 start = tranches[0].timestamp;
        uint40 step = (MAX_UNIX_TIMESTAMP - tranches[0].timestamp) / (trancheCount - 1);
        uint40 halfStep = step / 2;
        for (uint256 i = 1; i < trancheCount; ++i) {
            uint256 timestamp = start + i * step;
            timestamp = _bound(timestamp, timestamp - halfStep, timestamp + halfStep);
            tranches[i].timestamp = uint40(timestamp);
        }
    }

    /// @dev Just like {fuzzTranchedStreamAmounts} but with defaults.
    function fuzzTranchedStreamAmounts(
        LockupTranched.Tranche[] memory tranches,
        UD60x18 brokerFee
    )
        internal
        pure
        returns (uint128 totalAmount, Lockup.CreateAmounts memory createAmounts)
    {
        (totalAmount, createAmounts) =
            fuzzTranchedStreamAmounts({ upperBound: MAX_UINT128, tranches: tranches, brokerFee: brokerFee });
    }

    /// @dev Just like {fuzzTranchedStreamAmounts} but with defaults.
    function fuzzTranchedStreamAmounts(
        LockupTranched.TrancheWithDuration[] memory tranches,
        UD60x18 brokerFee
    )
        internal
        view
        returns (uint128 totalAmount, Lockup.CreateAmounts memory createAmounts)
    {
        LockupTranched.Tranche[] memory tranchesWithTimestamps = getTranchesWithTimestamps(tranches);
        (totalAmount, createAmounts) = fuzzTranchedStreamAmounts({
            upperBound: MAX_UINT128,
            tranches: tranchesWithTimestamps,
            brokerFee: brokerFee
        });
        for (uint256 i = 0; i < tranchesWithTimestamps.length; ++i) {
            tranches[i].amount = tranchesWithTimestamps[i].amount;
        }
    }

    /// @dev Fuzzes the tranche amounts and calculates the total and create amounts (deposit and broker fee).
    function fuzzTranchedStreamAmounts(
        uint128 upperBound,
        LockupTranched.TrancheWithDuration[] memory tranches,
        UD60x18 brokerFee
    )
        internal
        view
        returns (uint128 totalAmount, Lockup.CreateAmounts memory createAmounts)
    {
        LockupTranched.Tranche[] memory tranchesWithTimestamps = getTranchesWithTimestamps(tranches);
        (totalAmount, createAmounts) = fuzzTranchedStreamAmounts(upperBound, tranchesWithTimestamps, brokerFee);
        for (uint256 i = 0; i < tranchesWithTimestamps.length; ++i) {
            tranches[i].amount = tranchesWithTimestamps[i].amount;
        }
    }

    /// @dev Fuzzes the tranche amounts and calculates the total and create amounts (deposit and broker fee).
    function fuzzTranchedStreamAmounts(
        uint128 upperBound,
        LockupTranched.Tranche[] memory tranches,
        UD60x18 brokerFee
    )
        internal
        pure
        returns (uint128 totalAmount, Lockup.CreateAmounts memory createAmounts)
    {
        uint256 trancheCount = tranches.length;
        uint128 maxTrancheAmount = upperBound / uint128(trancheCount * 2);

        // Precompute the first tranche amount to prevent zero deposit amounts.
        tranches[0].amount = boundUint128(tranches[0].amount, 100, maxTrancheAmount);
        uint128 estimatedDepositAmount = tranches[0].amount;

        // Fuzz the other tranche amounts by bounding from 0.
        unchecked {
            for (uint256 i = 1; i < trancheCount; ++i) {
                tranches[i].amount = boundUint128(tranches[i].amount, 0, maxTrancheAmount);
                estimatedDepositAmount += tranches[i].amount;
            }
        }

        // Calculate the total amount from the approximated deposit amount (recall that the sum of all tranche amounts
        // must equal the deposit amount) using this formula:
        //
        // $$
        // total = \frac{deposit}{1e18 - brokerFee}
        // $$
        totalAmount = ud(estimatedDepositAmount).div(ud(uUNIT - brokerFee.intoUint256())).intoUint128();

        // Calculate the broker fee amount.
        createAmounts.brokerFee = ud(totalAmount).mul(brokerFee).intoUint128();

        // Here, we account for rounding errors and adjust the estimated deposit amount and the tranches. We know
        // that the estimated deposit amount is not greater than the adjusted deposit amount below, because the inverse
        // of {Helpers.checkAndCalculateBrokerFee} over-expresses the weight of the broker fee.
        createAmounts.deposit = totalAmount - createAmounts.brokerFee;
        tranches[tranches.length - 1].amount += (createAmounts.deposit - estimatedDepositAmount);
    }
}
