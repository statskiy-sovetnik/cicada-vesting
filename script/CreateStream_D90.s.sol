// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CreateStreamBase, IERC20 } from "./CreateStreamBase.sol";

contract CreateStream_D90 is CreateStreamBase {
    function _cliffDays() internal override pure returns (uint40) {
        return 90;
    }

    function _cliffUnlockAmount() internal override view returns (uint128) {
        uint8 decimals = IERC20(TOKEN_ADDR).decimals();
        return 20 * uint128(10 ** decimals); // TODO: set 20% tranche
    }
}
