// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC4906 } from "@openzeppelin/contracts/interfaces/IERC4906.sol";

import { ISablierLockupBase } from "src/interfaces/ISablierLockupBase.sol";
import { Errors } from "src/libraries/Errors.sol";
import { Lockup } from "src/types/DataTypes.sol";

import { Integration_Test } from "../../../Integration.t.sol";

abstract contract Withdraw_Integration_Concrete_Test is Integration_Test {
    address internal caller;

    function test_RevertWhen_DelegateCall() external {
        uint128 withdrawAmount = defaults.WITHDRAW_AMOUNT();
        expectRevert_DelegateCall({
            callData: abi.encodeCall(lockup.withdraw, (defaultStreamId, users.recipient, withdrawAmount))
        });
    }

    function test_RevertGiven_Null() external whenNoDelegateCall {
        uint128 withdrawAmount = defaults.WITHDRAW_AMOUNT();
        expectRevert_Null({ callData: abi.encodeCall(lockup.withdraw, (nullStreamId, users.recipient, withdrawAmount)) });
    }

    function test_RevertGiven_DEPLETEDStatus() external whenNoDelegateCall givenNotNull {
        expectRevert_DEPLETEDStatus({
            callData: abi.encodeCall(lockup.withdraw, (defaultStreamId, users.recipient, defaults.WITHDRAW_AMOUNT()))
        });
    }

    function test_RevertWhen_WithdrawalAddressZero() external whenNoDelegateCall givenNotNull givenNotDEPLETEDStatus {
        uint128 withdrawAmount = defaults.WITHDRAW_AMOUNT();
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierLockupBase_WithdrawToZeroAddress.selector, defaultStreamId)
        );
        lockup.withdraw({ streamId: defaultStreamId, to: address(0), amount: withdrawAmount });
    }

    function test_RevertWhen_ZeroWithdrawAmount()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
    {
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierLockupBase_WithdrawAmountZero.selector, defaultStreamId));
        lockup.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: 0 });
    }

    function test_RevertWhen_WithdrawAmountOverdraws()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
        whenNonZeroWithdrawAmount
    {
        uint128 withdrawableAmount = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierLockupBase_Overdraw.selector, defaultStreamId, MAX_UINT128, withdrawableAmount
            )
        );
        lockup.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: MAX_UINT128 });
    }

    modifier whenWithdrawalAddressNotRecipient(bool isCallerRecipient) {
        if (!isCallerRecipient) {
            // When caller is unknown.
            caller = users.eve;
            resetPrank({ msgSender: caller });
            _;

            // When caller is sender.
            caller = users.sender;
            resetPrank({ msgSender: caller });
            _;

            // When caller is a former recipient.
            caller = users.recipient;
            resetPrank({ msgSender: caller });
            lockup.transferFrom(caller, users.eve, defaultStreamId);
            _;
        } else {
            // When caller is approved third party.
            caller = users.operator;
            resetPrank({ msgSender: caller });
            _;

            // When caller is recipient.
            caller = users.recipient;
            resetPrank({ msgSender: caller });
            _;
        }
    }

    function test_RevertWhen_CallerNotApprovedThirdPartyOrRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
        whenNonZeroWithdrawAmount
        whenWithdrawAmountNotOverdraw
        whenWithdrawalAddressNotRecipient(false)
    {
        // Simulate the passage of time.
        vm.warp({ newTimestamp: defaults.WARP_26_PERCENT() });

        // Set the withdraw amount to the default amount.
        uint128 withdrawAmount = defaults.WITHDRAW_AMOUNT();

        // It should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierLockupBase_WithdrawalAddressNotRecipient.selector, defaultStreamId, caller, users.alice
            )
        );
        lockup.withdraw({ streamId: defaultStreamId, to: users.alice, amount: withdrawAmount });
    }

    function test_WhenCallerApprovedThirdPartyOrRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
        whenNonZeroWithdrawAmount
        whenWithdrawAmountNotOverdraw
        whenWithdrawalAddressNotRecipient(true)
    {
        // Simulate the passage of time.
        vm.warp({ newTimestamp: defaults.WARP_26_PERCENT() });

        // Set the withdraw amount to the default amount.
        uint128 withdrawAmount = defaults.WITHDRAW_AMOUNT() / 2;

        uint128 previousWithdrawnAmount = lockup.getWithdrawnAmount(defaultStreamId);

        // It should emit {WithdrawFromLockupStream} and {MetadataUpdate} events.
        vm.expectEmit({ emitter: address(lockup) });
        emit ISablierLockupBase.WithdrawFromLockupStream({
            streamId: defaultStreamId,
            to: users.alice,
            token: dai,
            amount: withdrawAmount
        });
        vm.expectEmit({ emitter: address(lockup) });
        emit IERC4906.MetadataUpdate({ _tokenId: defaultStreamId });

        // Make the withdrawal.
        lockup.withdraw({ streamId: defaultStreamId, to: users.alice, amount: withdrawAmount });

        // It should update the withdrawn amount.
        uint128 actualWithdrawnAmount = lockup.getWithdrawnAmount(defaultStreamId);
        uint128 expectedWithdrawnAmount = previousWithdrawnAmount + withdrawAmount;
        assertEq(actualWithdrawnAmount, expectedWithdrawnAmount, "withdrawnAmount");
    }

    function test_WhenCallerUnknown()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
        whenNonZeroWithdrawAmount
        whenWithdrawAmountNotOverdraw
        whenWithdrawalAddressRecipient
    {
        // Make the unknown address the caller in this test.
        resetPrank({ msgSender: address(0xCAFE) });

        // Simulate the passage of time.
        vm.warp({ newTimestamp: defaults.WARP_26_PERCENT() });

        // Make the withdrawal.
        lockup.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: defaults.WITHDRAW_AMOUNT() });

        // It should update the withdrawn amount.
        uint128 actualWithdrawnAmount = lockup.getWithdrawnAmount(defaultStreamId);
        uint128 expectedWithdrawnAmount = defaults.WITHDRAW_AMOUNT();
        assertEq(actualWithdrawnAmount, expectedWithdrawnAmount, "withdrawnAmount");
    }

    function test_WhenCallerRecipient()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
        whenNonZeroWithdrawAmount
        whenWithdrawAmountNotOverdraw
        whenWithdrawalAddressRecipient
    {
        resetPrank({ msgSender: users.recipient });

        // Simulate the passage of time.
        vm.warp({ newTimestamp: defaults.WARP_26_PERCENT() });

        // Make the withdrawal.
        lockup.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: defaults.WITHDRAW_AMOUNT() });

        // It should update the withdrawn amount.
        uint128 actualWithdrawnAmount = lockup.getWithdrawnAmount(defaultStreamId);
        uint128 expectedWithdrawnAmount = defaults.WITHDRAW_AMOUNT();
        assertEq(actualWithdrawnAmount, expectedWithdrawnAmount, "withdrawnAmount");
    }

    function test_GivenEndTimeNotInFuture()
        external
        whenNoDelegateCall
        givenNotNull
        givenNotDEPLETEDStatus
        whenWithdrawalAddressNotZero
        whenNonZeroWithdrawAmount
        whenWithdrawAmountNotOverdraw
        whenWithdrawalAddressRecipient
        whenCallerSender
    {
        // Warp to the stream's end.
        vm.warp({ newTimestamp: defaults.END_TIME() });

        // Make the withdrawal.
        lockup.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: defaults.DEPOSIT_AMOUNT() });

        // It should mark the stream as depleted.
        Lockup.Status actualStatus = lockup.statusOf(defaultStreamId);
        Lockup.Status expectedStatus = Lockup.Status.DEPLETED;
        assertEq(actualStatus, expectedStatus);


        // Assert that the not burned NFT.
        address actualNFTowner = lockup.ownerOf({ tokenId: defaultStreamId });
        address expectedNFTOwner = users.recipient;
        assertEq(actualNFTowner, expectedNFTOwner, "NFT owner");
    }






}
