// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { Lockup } from "src/types/DataTypes.sol";

import { Integration_Test } from "../../Integration.t.sol";
import { Withdraw_Integration_Concrete_Test } from "../lockup-base/withdraw/withdraw.t.sol";

abstract contract Lockup_Tranched_Integration_Concrete_Test is Integration_Test {
    function setUp() public virtual override {
        Integration_Test.setUp();

        lockupModel = Lockup.Model.LOCKUP_TRANCHED;
        initializeDefaultStreams();
    }
}

/*//////////////////////////////////////////////////////////////////////////
                                SHARED TESTS
//////////////////////////////////////////////////////////////////////////*/

contract Withdraw_Lockup_Tranched_Integration_Concrete_Test is
    Lockup_Tranched_Integration_Concrete_Test,
    Withdraw_Integration_Concrete_Test
{
    function setUp() public virtual override(Lockup_Tranched_Integration_Concrete_Test, Integration_Test) {
        Lockup_Tranched_Integration_Concrete_Test.setUp();
    }
}
