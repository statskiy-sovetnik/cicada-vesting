// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { Lockup, LockupDynamic, LockupLinear, LockupTranched } from "../types/DataTypes.sol";
import { ISablierLockupBase } from "./ISablierLockupBase.sol";

/// @title ISablierLockup
/// @notice Creates and manages Lockup streams with various distribution models.
interface ISablierLockup is ISablierLockupBase {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a stream is created using Lockup dynamic model.
    /// @param streamId The ID of the newly created stream.
    /// @param commonParams Common parameters emitted in Create events across all Lockup models.
    /// @param segments The segments the protocol uses to compose the dynamic distribution function.
    event CreateLockupDynamicStream(
        uint256 indexed streamId, Lockup.CreateEventCommon commonParams, LockupDynamic.Segment[] segments
    );

    /// @notice Emitted when a stream is created using Lockup linear model.
    /// @param streamId The ID of the newly created stream.
    /// @param commonParams Common parameters emitted in Create events across all Lockup models.
    /// @param cliffTime The Unix timestamp for the cliff period's end. A value of zero means there is no cliff.
    /// @param unlockAmounts Struct encapsulating (i) the amount to unlock at the start time and (ii) the amount to
    /// unlock at the cliff time.
    event CreateLockupLinearStream(
        uint256 indexed streamId,
        Lockup.CreateEventCommon commonParams,
        uint40 cliffTime,
        LockupLinear.UnlockAmounts unlockAmounts
    );

    /*//////////////////////////////////////////////////////////////////////////
                                 CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The maximum number of segments and tranches allowed in Dynamic and Tranched streams respectively.
    /// @dev This is initialized at construction time and cannot be changed later.
    function MAX_COUNT() external view returns (uint256);

    /// @notice Retrieves the stream's cliff time, which is a Unix timestamp.  A value of zero means there is no cliff.
    /// @dev Reverts if `streamId` references a null stream or a non Lockup Linear stream.
    /// @param streamId The stream ID for the query.
    function getCliffTime(uint256 streamId) external view returns (uint40 cliffTime);

    /// @notice Retrieves the segments used to compose the dynamic distribution function.
    /// @dev Reverts if `streamId` references a null stream or a non Lockup Dynamic stream.
    /// @param streamId The stream ID for the query.
    /// @return segments See the documentation in {DataTypes}.
    function getSegments(uint256 streamId) external view returns (LockupDynamic.Segment[] memory segments);

    /// @notice Retrieves the tranches used to compose the tranched distribution function.
    /// @dev Reverts if `streamId` references a null stream or a non Lockup Tranched stream.
    /// @param streamId The stream ID for the query.
    /// @return tranches See the documentation in {DataTypes}.
    function getTranches(uint256 streamId) external view returns (LockupTranched.Tranche[] memory tranches);

    /// @notice Retrieves the unlock amounts used to compose the linear distribution function.
    /// @dev Reverts if `streamId` references a null stream or a non Lockup Linear stream.
    /// @param streamId The stream ID for the query.
    /// @return unlockAmounts See the documentation in {DataTypes}.
    function getUnlockAmounts(uint256 streamId)
        external
        view
        returns (LockupLinear.UnlockAmounts memory unlockAmounts);

    /*//////////////////////////////////////////////////////////////////////////
                               NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a stream by setting the start time to `block.timestamp`, and the end time to
    /// the sum of `block.timestamp` and `durations.total`. The stream is funded by `msg.sender` and is wrapped in an
    /// ERC-721 NFT.
    ///
    /// @dev Emits a {Transfer}, {CreateLockupLinearStream} and {MetadataUpdate} event.
    ///
    /// Requirements:
    /// - All requirements in {createWithTimestampsLL} must be met for the calculated parameters.
    ///
    /// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
    /// @param durations Struct encapsulating (i) cliff period duration and (ii) total stream duration, both in seconds.
    /// @param unlockAmounts Struct encapsulating (i) the amount to unlock at the start time and (ii) the amount to
    /// unlock at the cliff time.
    /// @return streamId The ID of the newly created stream.
    function createWithDurationsLL(
        Lockup.CreateWithDurations calldata params,
        LockupLinear.UnlockAmounts calldata unlockAmounts,
        LockupLinear.Durations calldata durations
    )
        external
        payable
        returns (uint256 streamId);
    

    /// @notice Creates a stream with the provided start time and end time. The stream is funded by `msg.sender` and is
    /// wrapped in an ERC-721 NFT.
    ///
    /// @dev Emits a {Transfer}, {CreateLockupLinearStream} and {MetadataUpdate} event.
    ///
    /// Notes:
    /// - A cliff time of zero means there is no cliff.
    /// - As long as the times are ordered, it is not an error for the start or the cliff time to be in the past.
    ///
    /// Requirements:
    /// - Must not be delegate called.
    /// - `params.totalAmount` must be greater than zero.
    /// - If set, `params.broker.fee` must not be greater than `MAX_BROKER_FEE`.
    /// - `params.timestamps.start` must be greater than zero and less than `params.timestamps.end`.
    /// - If set, `cliffTime` must be greater than `params.timestamps.start` and less than
    /// `params.timestamps.end`.
    /// - `params.recipient` must not be the zero address.
    /// - `params.sender` must not be the zero address.
    /// - The sum of `params.unlockAmounts.start` and `params.unlockAmounts.cliff` must be less than or equal to
    /// deposit amount.
    /// - If `params.timestamps.cliff` not set, the `params.unlockAmounts.cliff` must be zero.
    /// - `msg.sender` must have allowed this contract to spend at least `params.totalAmount` tokens.
    /// - `params.shape.length` must not be greater than 32 characters.
    ///
    /// @param params Struct encapsulating the function parameters, which are documented in {DataTypes}.
    /// @param cliffTime The Unix timestamp for the cliff period's end. A value of zero means there is no cliff.
    /// @param unlockAmounts Struct encapsulating (i) the amount to unlock at the start time and (ii) the amount to
    /// unlock at the cliff time.
    /// @return streamId The ID of the newly created stream.
    function createWithTimestampsLL(
        Lockup.CreateWithTimestamps calldata params,
        LockupLinear.UnlockAmounts calldata unlockAmounts,
        uint40 cliffTime
    )
        external
        payable
        returns (uint256 streamId);

}
