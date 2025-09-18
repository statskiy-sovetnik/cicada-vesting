// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

import { PRBMathCastingUint128 as CastingUint128 } from "@prb/math/src/casting/Uint128.sol";
import { UD60x18, ud, uUNIT } from "@prb/math/src/UD60x18.sol";

import { Lockup } from "../../src/types/DataTypes.sol";

import { Constants } from "./Constants.sol";
import { Utils } from "./Utils.sol";

abstract contract Fuzzers is Constants, Utils {
    using CastingUint128 for uint128;

}
