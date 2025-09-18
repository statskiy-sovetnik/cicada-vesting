// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { UD60x18 } from "@prb/math/src/UD60x18.sol";

import { SablierLockup } from "src/SablierLockup.sol";

import { Integration_Test } from "../Integration.t.sol";

contract Constructor_Integration_Concrete_Test is Integration_Test {
    function test_Constructor() external {
        // Construct the contract.
        SablierLockup constructedLockup = new SablierLockup({
            maxCount: defaults.MAX_COUNT()
        });

        // {SablierLockupBase.constant}
        UD60x18 actualMaxBrokerFee = constructedLockup.MAX_BROKER_FEE();
        UD60x18 expectedMaxBrokerFee = UD60x18.wrap(0.1e18);
        assertEq(actualMaxBrokerFee, expectedMaxBrokerFee, "MAX_BROKER_FEE");

        // {SablierLockupBase.constructor}
        uint256 actualStreamId = constructedLockup.nextStreamId();
        uint256 expectedStreamId = 1;
        assertEq(actualStreamId, expectedStreamId, "nextStreamId");

        // {SablierLockupBase.supportsInterface}
        assertTrue(constructedLockup.supportsInterface(0x49064906), "ERC-4906 interface ID");

        // {SablierLockup.constructor}
        uint256 actualMaxCount = constructedLockup.MAX_COUNT();
        uint256 expectedMaxCount = defaults.MAX_COUNT();
        assertEq(actualMaxCount, expectedMaxCount, "MAX_COUNT");
    }
}
