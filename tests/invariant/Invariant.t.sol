// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { StdInvariant } from "forge-std/src/StdInvariant.sol";
import { Lockup } from "src/types/DataTypes.sol";
import { Base_Test } from "../Base.t.sol";
import { LockupCreateHandler } from "./handlers/LockupCreateHandler.sol";
import { LockupHandler } from "./handlers/LockupHandler.sol";
import { LockupStore } from "./stores/LockupStore.sol";

/// @notice Invariants of {SablierLockup} contract.
contract Invariant_Test is Base_Test, StdInvariant {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    LockupHandler internal handler;
    LockupStore internal lockupStore;
    LockupCreateHandler internal createHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Deploy and label the lockup store contract.
        lockupStore = new LockupStore();
        vm.label({ account: address(lockupStore), newLabel: "LockupStore" });

        // Deploy the Lockup handlers.
        createHandler = new LockupCreateHandler({ token_: dai, lockupStore_: lockupStore, lockup_: lockup });
        handler = new LockupHandler({ token_: dai, lockupStore_: lockupStore, lockup_: lockup });

        // Label the contracts.
        vm.label({ account: address(createHandler), newLabel: "LockupCreateHandler" });
        vm.label({ account: address(handler), newLabel: "LockupHandler" });

        // Target the Lockup handlers for invariant testing.
        targetContract(address(createHandler));
        targetContract(address(handler));

        // Exclude the lockup store from being fuzzed as `msg.sender`.
        excludeSender(address(createHandler));
        excludeSender(address(handler));
        excludeSender(address(lockup));
        excludeSender(address(lockupStore));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       COMMON
    //////////////////////////////////////////////////////////////////////////*/

    // solhint-disable max-line-length
    function invariant_ContractTokenBalance() external view {
        uint256 contractBalance = dai.balanceOf(address(lockup));

        uint256 lastStreamId = lockupStore.lastStreamId();
        uint256 depositedAmountsSum;
        uint256 withdrawnAmountsSum;
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            depositedAmountsSum += uint256(lockup.getDepositedAmount(streamId));
            withdrawnAmountsSum += uint256(lockup.getWithdrawnAmount(streamId));
        }

        assertGe(
            contractBalance,
            depositedAmountsSum - withdrawnAmountsSum,
            unicode"Invariant violation: contract balances < Σ deposited amounts - Σ withdrawn amounts"
        );
    }

    function invariant_DepositedAmountGteStreamedAmount() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            assertGe(
                lockup.getDepositedAmount(streamId),
                lockup.streamedAmountOf(streamId),
                "Invariant violation: deposited amount < streamed amount"
            );
        }
    }

    function invariant_DepositedAmountGteWithdrawableAmount() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            assertGe(
                lockup.getDepositedAmount(streamId),
                lockup.withdrawableAmountOf(streamId),
                "Invariant violation: deposited amount < withdrawable amount"
            );
        }
    }

    function invariant_DepositedAmountGteWithdrawnAmount() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            assertGe(
                lockup.getDepositedAmount(streamId),
                lockup.getWithdrawnAmount(streamId),
                "Invariant violation: deposited amount < withdrawn amount"
            );
        }
    }

    function invariant_DepositedAmountNotZero() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            uint128 depositAmount = lockup.getDepositedAmount(streamId);
            assertNotEq(depositAmount, 0, "Invariant violated: stream non-null, deposited amount zero");
        }
    }

    function invariant_EndTimeGtStartTime() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            assertGt(
                lockup.getEndTime(streamId),
                lockup.getStartTime(streamId),
                "Invariant violation: end time <= start time"
            );
        }
    }

    function invariant_NextStreamId() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 nextStreamId = lockup.nextStreamId();
            assertEq(nextStreamId, lastStreamId + 1, "Invariant violation: next stream ID not incremented");
        }
    }

    function invariant_StartTimeNotZero() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            uint40 startTime = lockup.getStartTime(streamId);
            assertGt(startTime, 0, "Invariant violated: start time zero");
        }
    }


    function invariant_StatusDepleted() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            if (lockup.isDepleted(streamId)) {
                assertEq(
                    lockup.getDepositedAmount(streamId),
                    lockup.getWithdrawnAmount(streamId),
                    "Invariant violation: depleted stream with deposited amount != withdrawn amount"
                );
                assertEq(
                    lockup.withdrawableAmountOf(streamId),
                    0,
                    "Invariant violation: depleted stream with a non-zero withdrawable amount"
                );
            }
        }
    }

    function invariant_StatusPending() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            if (lockup.statusOf(streamId) == Lockup.Status.PENDING) {
                assertEq(
                    lockup.getWithdrawnAmount(streamId),
                    0,
                    "Invariant violation: pending stream with a non-zero withdrawn amount"
                );
                assertEq(
                    lockup.streamedAmountOf(streamId),
                    0,
                    "Invariant violation: pending stream with a non-zero streamed amount"
                );
                assertEq(
                    lockup.withdrawableAmountOf(streamId),
                    0,
                    "Invariant violation: pending stream with a non-zero withdrawable amount"
                );
            }
        }
    }

    function invariant_StatusSettled() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            if (lockup.statusOf(streamId) == Lockup.Status.SETTLED) {
                assertEq(
                    lockup.streamedAmountOf(streamId),
                    lockup.getDepositedAmount(streamId),
                    "Invariant violation: settled stream with streamed amount != deposited amount"
                );
            }
        }
    }

    function invariant_StatusStreaming() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            if (lockup.statusOf(streamId) == Lockup.Status.STREAMING) {
                assertLt(
                    lockup.streamedAmountOf(streamId),
                    lockup.getDepositedAmount(streamId),
                    "Invariant violation: streaming stream with streamed amount >= deposited amount"
                );
            }
        }
    }

    /// @dev See diagram at https://docs.sablier.com/concepts/protocol/statuses#diagram
    function invariant_StatusTransitions() external {
        uint256 lastStreamId = lockupStore.lastStreamId();
        if (lastStreamId == 0) {
            return;
        }

        for (uint256 i = 0; i < lastStreamId - 1; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            Lockup.Status currentStatus = lockup.statusOf(streamId);

            // If this is the first time the status is checked for this stream, skip the invariant test.
            if (!lockupStore.isPreviousStatusRecorded(streamId)) {
                lockupStore.updateIsPreviousStatusRecorded(streamId);
                return;
            }

            // Check the status transition invariants.
            Lockup.Status previousStatus = lockupStore.previousStatusOf(streamId);
            if (previousStatus == Lockup.Status.PENDING) {
                assertNotEq(
                    currentStatus, Lockup.Status.DEPLETED, "Invariant violation: pending stream turned depleted"
                );
            } else if (previousStatus == Lockup.Status.STREAMING) {
                assertNotEq(
                    currentStatus, Lockup.Status.PENDING, "Invariant violation: streaming stream turned pending"
                );
            } else if (previousStatus == Lockup.Status.SETTLED) {
                assertNotEq(currentStatus, Lockup.Status.PENDING, "Invariant violation: settled stream turned pending");
                assertNotEq(
                    currentStatus, Lockup.Status.STREAMING, "Invariant violation: settled stream turned streaming"
                );
            } else if (previousStatus == Lockup.Status.DEPLETED) {
                assertEq(currentStatus, Lockup.Status.DEPLETED, "Invariant violation: depleted status changed");
            }

            // Set the current status as the previous status.
            lockupStore.updatePreviousStatusOf(streamId, currentStatus);
        }
    }

    function invariant_StreamedAmountGteWithdrawableAmount() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            assertGe(
                lockup.streamedAmountOf(streamId),
                lockup.withdrawableAmountOf(streamId),
                "Invariant violation: streamed amount < withdrawable amount"
            );
        }
    }

    function invariant_StreamedAmountGteWithdrawnAmount() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            assertGe(
                lockup.streamedAmountOf(streamId),
                lockup.getWithdrawnAmount(streamId),
                "Invariant violation: streamed amount < withdrawn amount"
            );
        }
    }


    /*//////////////////////////////////////////////////////////////////////////
                                   LOCKUP LINEAR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev If it is not zero, the cliff time must be strictly greater than the start time.
    function invariant_CliffTimeGtStartTimeOrZero() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            if (lockup.getLockupModel(streamId) == Lockup.Model.LOCKUP_LINEAR) {
                if (lockup.getCliffTime(streamId) > 0) {
                    assertGt(
                        lockup.getCliffTime(streamId),
                        lockup.getStartTime(streamId),
                        "Invariant violated: cliff time <= start time"
                    );
                }
            }
        }
    }

    /// @dev The end time must not be less than or equal to the cliff time.
    function invariant_EndTimeGtCliffTime() external view {
        uint256 lastStreamId = lockupStore.lastStreamId();
        for (uint256 i = 0; i < lastStreamId; ++i) {
            uint256 streamId = lockupStore.streamIds(i);
            if (lockup.getLockupModel(streamId) == Lockup.Model.LOCKUP_LINEAR) {
                assertGt(
                    lockup.getEndTime(streamId),
                    lockup.getCliffTime(streamId),
                    "Invariant violated: end time <= cliff time"
                );
            }
        }
    }
}
