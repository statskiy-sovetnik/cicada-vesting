// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { Lockup, LockupDynamic, LockupLinear, LockupTranched } from "./../types/DataTypes.sol";
import { Errors } from "./Errors.sol";

/// @title Helpers
/// @notice Library with functions needed to validate input parameters across lockup streams.
library Helpers {
    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculate the timestamps and return the segments.
    function calculateSegmentTimestamps(
        LockupDynamic.SegmentWithDuration[] memory segmentsWithDuration,
        uint40 startTime
    )
        public
        pure
        returns (LockupDynamic.Segment[] memory segmentsWithTimestamps)
    {
        uint256 segmentCount = segmentsWithDuration.length;
        segmentsWithTimestamps = new LockupDynamic.Segment[](segmentCount);

        // It is safe to use unchecked arithmetic because {SablierLockup._createLD} will nonetheless
        // check the correctness of the calculated segment timestamps.
        unchecked {
            // The first segment is precomputed because it is needed in the for loop below.
            segmentsWithTimestamps[0] = LockupDynamic.Segment({
                amount: segmentsWithDuration[0].amount,
                exponent: segmentsWithDuration[0].exponent,
                timestamp: startTime + segmentsWithDuration[0].duration
            });

            // Copy the segment amounts and exponents, and calculate the segment timestamps.
            for (uint256 i = 1; i < segmentCount; ++i) {
                segmentsWithTimestamps[i] = LockupDynamic.Segment({
                    amount: segmentsWithDuration[i].amount,
                    exponent: segmentsWithDuration[i].exponent,
                    timestamp: segmentsWithTimestamps[i - 1].timestamp + segmentsWithDuration[i].duration
                });
            }
        }
    }

    /// @dev Calculate the timestamps and return the tranches.
    function calculateTrancheTimestamps(
        LockupTranched.TrancheWithDuration[] memory tranchesWithDuration,
        uint40 startTime
    )
        public
        pure
        returns (LockupTranched.Tranche[] memory tranchesWithTimestamps)
    {
        uint256 trancheCount = tranchesWithDuration.length;
        tranchesWithTimestamps = new LockupTranched.Tranche[](trancheCount);

        // It is safe to use unchecked arithmetic because {SablierLockup-_createLT} will nonetheless check the
        // correctness of the calculated tranche timestamps.
        unchecked {
            // The first tranche is precomputed because it is needed in the for loop below.
            tranchesWithTimestamps[0] = LockupTranched.Tranche({
                amount: tranchesWithDuration[0].amount,
                timestamp: startTime + tranchesWithDuration[0].duration
            });

            // Copy the tranche amounts and calculate the tranche timestamps.
            for (uint256 i = 1; i < trancheCount; ++i) {
                tranchesWithTimestamps[i] = LockupTranched.Tranche({
                    amount: tranchesWithDuration[i].amount,
                    timestamp: tranchesWithTimestamps[i - 1].timestamp + tranchesWithDuration[i].duration
                });
            }
        }
    }

    /// @dev Checks the parameters of the {SablierLockup-_createLD} function.
    function checkCreateLockupDynamic(
        address sender,
        Lockup.Timestamps memory timestamps,
        uint128 totalAmount,
        LockupDynamic.Segment[] memory segments,
        uint256 maxCount,
        UD60x18 brokerFee,
        string memory shape,
        UD60x18 maxBrokerFee
    )
        public
        pure
        returns (Lockup.CreateAmounts memory createAmounts)
    {
        // Check: verify the broker fee and calculate the amounts.
        createAmounts = _checkAndCalculateBrokerFee(totalAmount, brokerFee, maxBrokerFee);

        // Check: validate the user-provided common parameters.
        _checkCreateStream(sender, createAmounts.deposit, timestamps.start, shape);

        // Check: validate the user-provided segments.
        _checkSegments(segments, createAmounts.deposit, timestamps, maxCount);
    }

    /// @dev Checks the parameters of the {SablierLockup-_createLL} function.
    function checkCreateLockupLinear(
        address sender,
        Lockup.Timestamps memory timestamps,
        uint40 cliffTime,
        uint128 totalAmount,
        LockupLinear.UnlockAmounts memory unlockAmounts,
        UD60x18 brokerFee,
        string memory shape,
        UD60x18 maxBrokerFee
    )
        public
        pure
        returns (Lockup.CreateAmounts memory createAmounts)
    {
        // Check: verify the broker fee and calculate the amounts.
        createAmounts = _checkAndCalculateBrokerFee(totalAmount, brokerFee, maxBrokerFee);

        // Check: validate the user-provided common parameters.
        _checkCreateStream(sender, createAmounts.deposit, timestamps.start, shape);

        // Check: validate the user-provided cliff and end times.
        _checkTimestampsAndUnlockAmounts(createAmounts.deposit, timestamps, cliffTime, unlockAmounts);
    }

    /// @dev Checks the parameters of the {SablierLockup-_createLT} function.
    function checkCreateLockupTranched(
        address sender,
        Lockup.Timestamps memory timestamps,
        uint128 totalAmount,
        LockupTranched.Tranche[] memory tranches,
        uint256 maxCount,
        UD60x18 brokerFee,
        string memory shape,
        UD60x18 maxBrokerFee
    )
        public
        pure
        returns (Lockup.CreateAmounts memory createAmounts)
    {
        // Check: verify the broker fee and calculate the amounts.
        createAmounts = _checkAndCalculateBrokerFee(totalAmount, brokerFee, maxBrokerFee);

        // Check: validate the user-provided common parameters.
        _checkCreateStream(sender, createAmounts.deposit, timestamps.start, shape);

        // Check: validate the user-provided segments.
        _checkTranches(tranches, createAmounts.deposit, timestamps, maxCount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            PRIVATE CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks the broker fee is not greater than `maxBrokerFee`, and then calculates the broker fee amount and
    /// the deposit amount from the total amount.
    function _checkAndCalculateBrokerFee(
        uint128 totalAmount,
        UD60x18 brokerFee,
        UD60x18 maxBrokerFee
    )
        private
        pure
        returns (Lockup.CreateAmounts memory amounts)
    {
        // When the total amount is zero, the broker fee is also zero.
        if (totalAmount == 0) {
            return Lockup.CreateAmounts(0, 0);
        }

        // If the broker fee is zero, the deposit amount is the total amount.
        if (brokerFee.isZero()) {
            return Lockup.CreateAmounts(totalAmount, 0);
        }

        // Check: the broker fee is not greater than `maxBrokerFee`.
        if (brokerFee.gt(maxBrokerFee)) {
            revert Errors.SablierHelpers_BrokerFeeTooHigh(brokerFee, maxBrokerFee);
        }

        // Calculate the broker fee amount.
        amounts.brokerFee = ud(totalAmount).mul(brokerFee).intoUint128();

        // Assert that the total amount is strictly greater than the broker fee amount.
        assert(totalAmount > amounts.brokerFee);

        // Calculate the deposit amount (the amount to stream, net of the broker fee).
        amounts.deposit = totalAmount - amounts.brokerFee;
    }

    /// @dev Checks the user-provided cliff, end times and unlock amounts of a lockup linear stream.
    function _checkTimestampsAndUnlockAmounts(
        uint128 depositAmount,
        Lockup.Timestamps memory timestamps,
        uint40 cliffTime,
        LockupLinear.UnlockAmounts memory unlockAmounts
    )
        private
        pure
    {
        // Since a cliff time of zero means there is no cliff, the following checks are performed only if it's not zero.
        if (cliffTime > 0) {
            // Check: the start time is strictly less than the cliff time.
            if (timestamps.start >= cliffTime) {
                revert Errors.SablierHelpers_StartTimeNotLessThanCliffTime(timestamps.start, cliffTime);
            }

            // Check: the cliff time is strictly less than the end time.
            if (cliffTime >= timestamps.end) {
                revert Errors.SablierHelpers_CliffTimeNotLessThanEndTime(cliffTime, timestamps.end);
            }
        }
        // Check: the cliff unlock amount is zero when the cliff time is zero.
        else if (unlockAmounts.cliff > 0) {
            revert Errors.SablierHelpers_CliffTimeZeroUnlockAmountNotZero(unlockAmounts.cliff);
        }

        // Check: the start time is strictly less than the end time.
        if (timestamps.start >= timestamps.end) {
            revert Errors.SablierHelpers_StartTimeNotLessThanEndTime(timestamps.start, timestamps.end);
        }

        // Check: the sum of the start and cliff unlock amounts is not greater than the deposit amount.
        if (unlockAmounts.start + unlockAmounts.cliff > depositAmount) {
            revert Errors.SablierHelpers_UnlockAmountsSumTooHigh(
                depositAmount, unlockAmounts.start, unlockAmounts.cliff
            );
        }
    }

    /// @dev Checks the user-provided common parameters across lockup streams.
    function _checkCreateStream(
        address sender,
        uint128 depositAmount,
        uint40 startTime,
        string memory shape
    )
        private
        pure
    {
        // Check: the sender is not the zero address.
        if (sender == address(0)) {
            revert Errors.SablierHelpers_SenderZeroAddress();
        }

        // Check: the deposit amount is not zero.
        if (depositAmount == 0) {
            revert Errors.SablierHelpers_DepositAmountZero();
        }

        // Check: the start time is not zero.
        if (startTime == 0) {
            revert Errors.SablierHelpers_StartTimeZero();
        }

        // Check: the shape is not greater than 32 bytes.
        if (bytes(shape).length > 32) {
            revert Errors.SablierHelpers_ShapeExceeds32Bytes(bytes(shape).length);
        }
    }

    /// @dev Checks:
    ///
    /// 1. The first timestamp is strictly greater than the start time.
    /// 2. The timestamps are ordered chronologically.
    /// 3. There are no duplicate timestamps.
    /// 4. The deposit amount is equal to the sum of all segment amounts.
    /// 5. The end time equals the last segment's timestamp.
    function _checkSegments(
        LockupDynamic.Segment[] memory segments,
        uint128 depositAmount,
        Lockup.Timestamps memory timestamps,
        uint256 maxSegmentCount
    )
        private
        pure
    {
        // Check: the segment count is not zero.
        uint256 segmentCount = segments.length;
        if (segmentCount == 0) {
            revert Errors.SablierHelpers_SegmentCountZero();
        }

        // Check: the segment count is not greater than the maximum allowed.
        if (segmentCount > maxSegmentCount) {
            revert Errors.SablierHelpers_SegmentCountTooHigh(segmentCount);
        }

        // Check: the start time is strictly less than the first segment timestamp.
        if (timestamps.start >= segments[0].timestamp) {
            revert Errors.SablierHelpers_StartTimeNotLessThanFirstSegmentTimestamp(
                timestamps.start, segments[0].timestamp
            );
        }

        // Check: the end time equals the last segment's timestamp.
        if (timestamps.end != segments[segmentCount - 1].timestamp) {
            revert Errors.SablierHelpers_EndTimeNotEqualToLastSegmentTimestamp(
                timestamps.end, segments[segmentCount - 1].timestamp
            );
        }

        // Pre-declare the variables needed in the for loop.
        uint128 segmentAmountsSum;
        uint40 currentSegmentTimestamp;
        uint40 previousSegmentTimestamp;

        // Iterate over the segments to:
        //
        // 1. Calculate the sum of all segment amounts.
        // 2. Check that the timestamps are ordered.
        for (uint256 index = 0; index < segmentCount; ++index) {
            // Add the current segment amount to the sum.
            segmentAmountsSum += segments[index].amount;

            // Check: the current timestamp is strictly greater than the previous timestamp.
            currentSegmentTimestamp = segments[index].timestamp;
            if (currentSegmentTimestamp <= previousSegmentTimestamp) {
                revert Errors.SablierHelpers_SegmentTimestampsNotOrdered(
                    index, previousSegmentTimestamp, currentSegmentTimestamp
                );
            }

            // Make the current timestamp the previous timestamp of the next loop iteration.
            previousSegmentTimestamp = currentSegmentTimestamp;
        }

        // Check: the deposit amount is equal to the segment amounts sum.
        if (depositAmount != segmentAmountsSum) {
            revert Errors.SablierHelpers_DepositAmountNotEqualToSegmentAmountsSum(depositAmount, segmentAmountsSum);
        }
    }

    /// @dev Checks:
    ///
    /// 1. The first timestamp is strictly greater than the start time.
    /// 2. The timestamps are ordered chronologically.
    /// 3. There are no duplicate timestamps.
    /// 4. The deposit amount is equal to the sum of all tranche amounts.
    /// 5. The end time equals the last tranche's timestamp.
    function _checkTranches(
        LockupTranched.Tranche[] memory tranches,
        uint128 depositAmount,
        Lockup.Timestamps memory timestamps,
        uint256 maxTrancheCount
    )
        private
        pure
    {
        // Check: the tranche count is not zero.
        uint256 trancheCount = tranches.length;
        if (trancheCount == 0) {
            revert Errors.SablierHelpers_TrancheCountZero();
        }

        // Check: the tranche count is not greater than the maximum allowed.
        if (trancheCount > maxTrancheCount) {
            revert Errors.SablierHelpers_TrancheCountTooHigh(trancheCount);
        }

        // Check: the start time is strictly less than the first tranche timestamp.
        if (timestamps.start >= tranches[0].timestamp) {
            revert Errors.SablierHelpers_StartTimeNotLessThanFirstTrancheTimestamp(
                timestamps.start, tranches[0].timestamp
            );
        }

        // Check: the end time equals the tranche's timestamp.
        if (timestamps.end != tranches[trancheCount - 1].timestamp) {
            revert Errors.SablierHelpers_EndTimeNotEqualToLastTrancheTimestamp(
                timestamps.end, tranches[trancheCount - 1].timestamp
            );
        }

        // Pre-declare the variables needed in the for loop.
        uint128 trancheAmountsSum;
        uint40 currentTrancheTimestamp;
        uint40 previousTrancheTimestamp;

        // Iterate over the tranches to:
        //
        // 1. Calculate the sum of all tranche amounts.
        // 2. Check that the timestamps are ordered.
        for (uint256 index = 0; index < trancheCount; ++index) {
            // Add the current tranche amount to the sum.
            trancheAmountsSum += tranches[index].amount;

            // Check: the current timestamp is strictly greater than the previous timestamp.
            currentTrancheTimestamp = tranches[index].timestamp;
            if (currentTrancheTimestamp <= previousTrancheTimestamp) {
                revert Errors.SablierHelpers_TrancheTimestampsNotOrdered(
                    index, previousTrancheTimestamp, currentTrancheTimestamp
                );
            }

            // Make the current timestamp the previous timestamp of the next loop iteration.
            previousTrancheTimestamp = currentTrancheTimestamp;
        }

        // Check: the deposit amount is equal to the tranche amounts sum.
        if (depositAmount != trancheAmountsSum) {
            revert Errors.SablierHelpers_DepositAmountNotEqualToTrancheAmountsSum(depositAmount, trancheAmountsSum);
        }
    }
}
