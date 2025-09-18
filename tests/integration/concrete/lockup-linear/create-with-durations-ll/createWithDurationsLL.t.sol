// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC4906 } from "@openzeppelin/contracts/interfaces/IERC4906.sol";

import { ISablierLockup } from "src/interfaces/ISablierLockup.sol";
import { Lockup, LockupLinear } from "src/types/DataTypes.sol";

import { Lockup_Linear_Integration_Concrete_Test } from "../LockupLinear.t.sol";

contract CreateWithDurationsLL_Integration_Concrete_Test is Lockup_Linear_Integration_Concrete_Test {
    function test_RevertWhen_DelegateCall() external {
        expectRevert_DelegateCall({
            callData: abi.encodeCall(
                lockup.createWithDurationsLL,
                (_defaultParams.createWithDurations, _defaultParams.unlockAmounts, _defaultParams.durations)
            )
        });
    }

    function test_WhenCliffDurationNotZero() external whenNoDelegateCall {
        _test_CreateWithDurations(_defaultParams.durations);
    }

    function test_WhenCliffDurationZero() external whenNoDelegateCall {
        _defaultParams.durations.cliff = 0;
        _test_CreateWithDurations(_defaultParams.durations);
    }

    function _test_CreateWithDurations(LockupLinear.Durations memory durations) private {
        // Make the Sender the stream's funder
        address funder = users.sender;
        uint256 expectedStreamId = lockup.nextStreamId();

        // Declare the timestamps.
        uint40 blockTimestamp = getBlockTimestamp();
        Lockup.Timestamps memory timestamps =
            Lockup.Timestamps({ start: blockTimestamp, end: blockTimestamp + durations.total });

        uint40 cliffTime;
        if (durations.cliff > 0) {
            cliffTime = blockTimestamp + durations.cliff;
        } else {
            _defaultParams.unlockAmounts.cliff = 0;
        }

        // It should perform the ERC-20 transfers.
        expectCallToTransferFrom({ from: funder, to: address(lockup), value: defaults.DEPOSIT_AMOUNT() });

        // Expect the broker fee to be paid to the broker.
        expectCallToTransferFrom({ from: funder, to: users.broker, value: defaults.BROKER_FEE_AMOUNT() });

        // It should emit {CreateLockupLinearStream} and {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC4906.MetadataUpdate({ _tokenId: expectedStreamId });
        vm.expectEmit({ emitter: address(lockup) });
        emit ISablierLockup.CreateLockupLinearStream({
            streamId: expectedStreamId,
            commonParams: defaults.lockupCreateEvent(timestamps),
            cliffTime: cliffTime,
            unlockAmounts: _defaultParams.unlockAmounts
        });

        // Create the stream.
        _defaultParams.durations = durations;
        uint256 streamId = createDefaultStreamWithDurations();

        // It should create the stream.
        assertEq(lockup.getCliffTime(streamId), cliffTime, "cliffTime");
        assertEq(lockup.getEndTime(streamId), timestamps.end, "endTime");
        assertFalse(lockup.isDepleted(streamId), "isDepleted");
        assertTrue(lockup.isStream(streamId), "isStream");
        assertEq(lockup.getLockupModel(streamId), Lockup.Model.LOCKUP_LINEAR);
        assertEq(lockup.getRecipient(streamId), users.recipient, "recipient");
        assertEq(lockup.getStartTime(streamId), timestamps.start, "startTime");
        assertEq(lockup.getUnderlyingToken(streamId), dai, "underlyingToken");
        assertEq(lockup.getUnlockAmounts(streamId).start, _defaultParams.unlockAmounts.start, "unlockAmounts.start");
        assertEq(lockup.getUnlockAmounts(streamId).cliff, _defaultParams.unlockAmounts.cliff, "unlockAmounts.cliff");

        // Assert that the stream's status is "STREAMING".
        Lockup.Status actualStatus = lockup.statusOf(streamId);
        Lockup.Status expectedStatus = Lockup.Status.STREAMING;
        assertEq(actualStatus, expectedStatus);

        // It should bump the next stream ID.
        uint256 actualNextStreamId = lockup.nextStreamId();
        uint256 expectedNextStreamId = streamId + 1;
        assertEq(actualNextStreamId, expectedNextStreamId, "nextStreamId");

        // It should mint the NFT.
        address actualNFTOwner = lockup.ownerOf({ tokenId: streamId });
        address expectedNFTOwner = users.recipient;
        assertEq(actualNFTOwner, expectedNFTOwner, "NFT owner");
    }
}
