// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { PRBMathCastingUint128 as CastingUint128 } from "@prb/math/src/casting/Uint128.sol";
import { PRBMathCastingUint40 as CastingUint40 } from "@prb/math/src/casting/Uint40.sol";
import { SD59x18 } from "@prb/math/src/SD59x18.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";

import { LockupLinear, LockupTranched } from "../../src/types/DataTypes.sol";

abstract contract Calculations {
    using CastingUint128 for uint128;
    using CastingUint40 for uint40;

    /// @dev Calculates the deposit amount by calculating and subtracting the broker fee amount from the total amount.
    function calculateDepositAmount(uint128 totalAmount, UD60x18 brokerFee) internal pure returns (uint128) {
        uint128 brokerFeeAmount = ud(totalAmount).mul(brokerFee).intoUint128();
        return totalAmount - brokerFeeAmount;
    }


    /// @dev Helper function that replicates the logic of {VestingMath.calculateLockupLinearStreamedAmount}.
    function calculateLockupLinearStreamedAmount(
        uint40 startTime,
        uint40 cliffTime,
        uint40 endTime,
        uint128 depositAmount,
        LockupLinear.UnlockAmounts memory unlockAmounts
    )
        internal
        view
        returns (uint128)
    {
        uint40 blockTimestamp = uint40(block.timestamp);

        if (startTime >= blockTimestamp) {
            return 0;
        }
        if (blockTimestamp >= endTime) {
            return depositAmount;
        }
        if (cliffTime > blockTimestamp) {
            return unlockAmounts.start;
        }

        unchecked {
            UD60x18 unlockAmountsSum = ud(unlockAmounts.start).add(ud(unlockAmounts.cliff));

            if (unlockAmountsSum.unwrap() >= depositAmount) {
                return depositAmount;
            }

            UD60x18 elapsedTime = cliffTime > 0 ? ud(blockTimestamp - cliffTime) : ud(blockTimestamp - startTime);
            UD60x18 streamableDuration = cliffTime > 0 ? ud(endTime - cliffTime) : ud(endTime - startTime);
            UD60x18 elapsedTimePercentage = elapsedTime.div(streamableDuration);

            UD60x18 streamableAmount = ud(depositAmount).sub(unlockAmountsSum);
            UD60x18 streamedAmount = elapsedTimePercentage.mul(streamableAmount);
            return streamedAmount.add(unlockAmountsSum).intoUint128();
        }
    }

    /// @dev Helper function that replicates the logic of {VestingMath.calculateLockupTranchedStreamedAmount}.
    function calculateLockupTranchedStreamedAmount(
        LockupTranched.Tranche[] memory tranches,
        uint128 depositAmount
    )
        internal
        view
        returns (uint128)
    {
        uint40 blockTimestamp = uint40(block.timestamp);
        if (blockTimestamp >= tranches[tranches.length - 1].timestamp) {
            return depositAmount;
        }

        // Sum the amounts in all tranches that precede the block timestamp.
        uint128 streamedAmount = tranches[0].amount;
        uint40 currentTrancheTimestamp = tranches[1].timestamp;
        uint256 index = 1;

        // Using unchecked arithmetic is safe because the tranches amounts sum equal to total amount at this point.
        unchecked {
            while (currentTrancheTimestamp <= blockTimestamp) {
                streamedAmount += tranches[index].amount;
                index += 1;
                currentTrancheTimestamp = tranches[index].timestamp;
            }
        }

        return streamedAmount;
    }
}
