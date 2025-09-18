// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { Errors } from "src/libraries/Errors.sol";
import { Lockup } from "src/types/DataTypes.sol";

import { Lockup_Linear_Integration_Concrete_Test } from "../LockupLinear.t.sol";

contract GetCliffTime_Integration_Concrete_Test is Lockup_Linear_Integration_Concrete_Test {
    function test_RevertGiven_Null() external {
        expectRevert_Null({ callData: abi.encodeCall(lockup.getCliffTime, nullStreamId) });
    }

    function test_GivenLinearModel() external view givenNotNull {
        uint40 actualCliffTime = lockup.getCliffTime(defaultStreamId);
        uint40 expectedCliffTime = defaults.CLIFF_TIME();
        assertEq(actualCliffTime, expectedCliffTime, "cliffTime");
    }
}
