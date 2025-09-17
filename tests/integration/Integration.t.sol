// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { Errors } from "src/libraries/Errors.sol";
import { Lockup, LockupLinear, LockupTranched } from "src/types/DataTypes.sol";

import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all integration tests, both concrete and fuzz tests.
abstract contract Integration_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Lockup.Model internal lockupModel;

    // Common stream IDs to be used across the tests.
    // Default stream ID.
    uint256 internal defaultStreamId;
    // A non-transferable stream ID.
    uint256 internal notTransferableStreamId;
    // A stream ID that does not exist.
    uint256 internal nullStreamId = 1729;

    struct CreateParams {
        Lockup.CreateWithTimestamps createWithTimestamps;
        Lockup.CreateWithDurations createWithDurations;
        uint40 cliffTime;
        LockupLinear.UnlockAmounts unlockAmounts;
        LockupLinear.Durations durations;
        LockupTranched.Tranche[] tranches;
        LockupTranched.TrancheWithDuration[] tranchesWithDurations;
    }

    CreateParams internal _defaultParams;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/


    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        _defaultParams.createWithTimestamps = defaults.createWithTimestamps();
        _defaultParams.createWithDurations = defaults.createWithDurations();
        _defaultParams.cliffTime = defaults.CLIFF_TIME();
        _defaultParams.durations = defaults.durations();
        _defaultParams.unlockAmounts = defaults.unlockAmounts();

        LockupTranched.TrancheWithDuration[] memory tranchesWithDurations = defaults.tranchesWithDurations();
        LockupTranched.Tranche[] memory tranches = defaults.tranches();
        for (uint256 i; i < defaults.TRANCHE_COUNT(); ++i) {
            _defaultParams.tranches.push(tranches[i]);
            _defaultParams.tranchesWithDurations.push(tranchesWithDurations[i]);
        }

        lockupModel = Lockup.Model.LOCKUP_TRANCHED;

        // Initialize default streams.
        initializeDefaultStreams();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                INITIALIZE-FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function initializeDefaultStreams() internal {
        defaultStreamId = createDefaultStream();
        notTransferableStreamId = createDefaultStreamNonTransferable();
    }


    /*//////////////////////////////////////////////////////////////////////////
                                    CREATE-DEFAULT
    //////////////////////////////////////////////////////////////////////////*/

    function createDefaultStream(Lockup.CreateWithTimestamps memory params) internal returns (uint256 streamId) {
        if (lockupModel == Lockup.Model.LOCKUP_LINEAR) {
            streamId = lockup.createWithTimestampsLL(params, _defaultParams.unlockAmounts, _defaultParams.cliffTime);
        } else if (lockupModel == Lockup.Model.LOCKUP_TRANCHED) {
            streamId = lockup.createWithTimestampsLT(params, _defaultParams.tranches);
        }
    }

    function createDefaultStream() internal returns (uint256 streamId) {
        streamId = createDefaultStream(_defaultParams.createWithTimestamps);
    }


    function createDefaultStreamNonTransferable() internal returns (uint256 streamId) {
        Lockup.CreateWithTimestamps memory params = _defaultParams.createWithTimestamps;
        params.transferable = false;
        streamId = createDefaultStream(params);
    }

    function createDefaultStreamWithDurations() internal returns (uint256 streamId) {
        if (lockupModel == Lockup.Model.LOCKUP_LINEAR) {
            streamId = lockup.createWithDurationsLL(
                _defaultParams.createWithDurations, _defaultParams.unlockAmounts, _defaultParams.durations
            );
        } else if (lockupModel == Lockup.Model.LOCKUP_TRANCHED) {
            streamId =
                lockup.createWithDurationsLT(_defaultParams.createWithDurations, _defaultParams.tranchesWithDurations);
        }
    }

    function createDefaultStreamWithEndTime(uint40 endTime) internal returns (uint256 streamId) {
        Lockup.CreateWithTimestamps memory params = _defaultParams.createWithTimestamps;
        params.timestamps.end = endTime;
        if (lockupModel == Lockup.Model.LOCKUP_LINEAR) {
            streamId = lockup.createWithTimestampsLL(params, _defaultParams.unlockAmounts, defaults.CLIFF_TIME());
        } else if (lockupModel == Lockup.Model.LOCKUP_TRANCHED) {
            LockupTranched.Tranche[] memory tranches = _defaultParams.tranches;
            tranches[1].timestamp = endTime;
            streamId = lockup.createWithTimestampsLT(params, tranches);
        }
    }

    function createDefaultStreamWithRecipient(address recipient) internal returns (uint256 streamId) {
        streamId = createDefaultStreamWithUsers(recipient, users.sender);
    }

    function createDefaultStreamWithUsers(address recipient, address sender) internal returns (uint256 streamId) {
        Lockup.CreateWithTimestamps memory params = _defaultParams.createWithTimestamps;
        params.recipient = recipient;
        params.sender = sender;
        streamId = createDefaultStream(params);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                COMMON-REVERT-TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function expectRevert_CallerMaliciousThirdParty(bytes memory callData) internal {
        resetPrank({ msgSender: users.eve });
        (bool success, bytes memory returnData) = address(lockup).call(callData);
        assertFalse(success, "malicious call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierLockupBase_Unauthorized.selector, defaultStreamId, users.eve),
            "malicious call return data"
        );
    }


    function expectRevert_DelegateCall(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(lockup).delegatecall(callData);
        assertFalse(success, "delegatecall success");
        assertEq(returnData, abi.encodeWithSelector(Errors.DelegateCall.selector), "delegatecall return data");
    }

    function expectRevert_DEPLETEDStatus(bytes memory callData) internal {
        vm.warp({ newTimestamp: defaults.END_TIME() });
        lockup.withdrawMax({ streamId: defaultStreamId, to: users.recipient });

        (bool success, bytes memory returnData) = address(lockup).call(callData);
        assertFalse(success, "depleted status call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierLockupBase_StreamDepleted.selector, defaultStreamId),
            "depleted status call return data"
        );
    }

    function expectRevert_Null(bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(lockup).call(callData);
        assertFalse(success, "null call success");
        assertEq(
            returnData,
            abi.encodeWithSelector(Errors.SablierLockupBase_Null.selector, nullStreamId),
            "null call return data"
        );
    }
}
