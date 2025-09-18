// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable event-name-camelcase
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PRBMathAssertions } from "@prb/math/test/utils/Assertions.sol";

import { Lockup } from "../../src/types/DataTypes.sol";

abstract contract Assertions is PRBMathAssertions {
    /*//////////////////////////////////////////////////////////////////////////
                                       EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Compares two {Lockup.Amounts} struct entities.
    function assertEq(Lockup.Amounts memory a, Lockup.Amounts memory b) internal pure {
        assertEq(a.deposited, b.deposited, "amounts.deposited");
        assertEq(a.refunded, b.refunded, "amounts.refunded");
        assertEq(a.withdrawn, b.withdrawn, "amounts.withdrawn");
    }

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b) internal pure {
        assertEq(address(a), address(b));
    }

    /// @dev Compares two {IERC20} values.
    function assertEq(IERC20 a, IERC20 b, string memory err) internal pure {
        assertEq(address(a), address(b), err);
    }

    /// @dev Compares two {Lockup.Model} enum values.
    function assertEq(Lockup.Model a, Lockup.Model b) internal pure {
        assertEq(uint8(a), uint8(b), "lockup model");
    }

    /// @dev Compares two {Lockup.Timestamps} struct entities.
    function assertEq(Lockup.Timestamps memory a, Lockup.Timestamps memory b) internal pure {
        assertEq(a.end, b.end, "timestamps.end");
        assertEq(a.start, b.start, "timestamps.start");
    }

    /// @dev Compares two {Lockup.Status} enum values.
    function assertEq(Lockup.Status a, Lockup.Status b) internal pure {
        assertEq(uint256(a), uint256(b), "status");
    }

    /// @dev Compares two {Lockup.Status} enum values.
    function assertEq(Lockup.Status a, Lockup.Status b, string memory err) internal pure {
        assertEq(uint256(a), uint256(b), err);
    }

    /// @dev Compares two {Lockup.Status} enum values.
    function assertNotEq(Lockup.Status a, Lockup.Status b) internal pure {
        assertNotEq(uint256(a), uint256(b), "status");
    }

    /// @dev Compares two {Lockup.Status} enum values.
    function assertNotEq(Lockup.Status a, Lockup.Status b, string memory err) internal pure {
        assertNotEq(uint256(a), uint256(b), err);
    }
}
