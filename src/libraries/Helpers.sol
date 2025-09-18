// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.22;

import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { Lockup, LockupLinear } from "./../types/DataTypes.sol";
import { Errors } from "./Errors.sol";

/// @title Helpers
/// @notice Library with functions needed to validate input parameters across lockup streams.
library Helpers {
    /*//////////////////////////////////////////////////////////////////////////
                                CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

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
}
