// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierLockup } from "src/interfaces/ISablierLockup.sol";

import { Base_Test } from "./../Base.t.sol";

/// @notice Common logic needed by all fork tests.
abstract contract Fork_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 internal immutable FORK_TOKEN;
    address internal forkTokenHolder;
    uint256 internal initialHolderBalance;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(IERC20 forkToken) {
        FORK_TOKEN = forkToken;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Fork Duckchain Mainnet at a specific block number.
        vm.createSelectFork({ blockNumber: 24_624_238, urlOrAlias: "https://rpc.duckchain.io" });

        // Load deployed addresses from Duckchain mainnet.
        lockup = ISablierLockup(0xE3fdbcaA4d01eae778D45053cf582e902fA6149E);

        // Create a custom user for this test suite.
        forkTokenHolder = payable(makeAddr(string.concat(IERC20Metadata(address(FORK_TOKEN)).symbol(), "_HOLDER")));

        // Label the addresses.
        labelContracts();

        // Deal token balance to the user.
        initialHolderBalance = 1e7 * 10 ** IERC20Metadata(address(FORK_TOKEN)).decimals();
        deal({ token: address(FORK_TOKEN), to: forkTokenHolder, give: initialHolderBalance });

        resetPrank({ msgSender: forkTokenHolder });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks the user assumptions.
    function checkUsers(address sender, address recipient, address broker, address lockupContract) internal virtual {
        // The protocol does not allow the zero address to interact with it.
        vm.assume(sender != address(0) && recipient != address(0) && broker != address(0));

        // The goal is to not have overlapping users because the forked token balance tests would fail otherwise.
        vm.assume(sender != recipient && sender != broker && recipient != broker);
        vm.assume(sender != forkTokenHolder && recipient != forkTokenHolder && broker != forkTokenHolder);
        vm.assume(sender != lockupContract && recipient != lockupContract && broker != lockupContract);

    }

    /// @dev Labels the most relevant addresses.
    function labelContracts() internal {
        vm.label({ account: address(FORK_TOKEN), newLabel: IERC20Metadata(address(FORK_TOKEN)).symbol() });
        vm.label({ account: forkTokenHolder, newLabel: "Fork Token Holder" });
    }
}
