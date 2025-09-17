// SPDX-License-Identifier: UNLICENSED
// solhint-disable no-inline-assembly
pragma solidity >=0.8.22 <0.9.0;

import { CommonBase } from "forge-std/src/Base.sol";
import { StdCheats } from "forge-std/src/StdCheats.sol";
import { stdJson } from "forge-std/src/StdJson.sol";

import { ISablierLockup } from "../../src/interfaces/ISablierLockup.sol";

abstract contract DeployOptimized is StdCheats, CommonBase {
    using stdJson for string;

    /// @dev Deploys the optimized {Helpers} and {VestingMath} libraries.
    function deployOptimizedLibraries() internal returns (address helpers, address vestingMath) {
        // Deploy public libraries.
        helpers = deployCode("out-optimized/Helpers.sol/Helpers.json");
        vestingMath = deployCode("out-optimized/VestingMath.sol/VestingMath.json");
    }

    /// @dev Deploys {SablierLockup} from an optimized source compiled with `--via-ir`.
    function deployOptimizedLockup(
        address initialAdmin,
        uint256 maxCount
    )
        internal
        returns (ISablierLockup lockup)
    {
        // Deploy the libraries.
        (address helpers, address vestingMath) = deployOptimizedLibraries();

        // Get the bytecode from {SablierLockup} artifact.
        string memory artifactJson = vm.readFile("out-optimized/SablierLockup.sol/SablierLockup.json");
        string memory rawBytecode = artifactJson.readString(".bytecode.object");

        // Replace the library placeholders with the library addresses to link the libraries with the contract.
        rawBytecode = vm.replace({
            input: rawBytecode,
            from: libraryPlaceholder("src/libraries/Helpers.sol:Helpers"),
            to: vm.replace(vm.toString(helpers), "0x", "")
        });
        rawBytecode = vm.replace({
            input: rawBytecode,
            from: libraryPlaceholder("src/libraries/VestingMath.sol:VestingMath"),
            to: vm.replace(vm.toString(vestingMath), "0x", "")
        });

        // Generate the creation bytecode with the constructor arguments.
        bytes memory createBytecode =
            bytes.concat(vm.parseBytes(rawBytecode), abi.encode(initialAdmin, maxCount));
        assembly {
            // Deploy the Lockup contract.
            lockup := create(0, add(createBytecode, 0x20), mload(createBytecode))
        }

        require(address(lockup) != address(0), "Lockup deployment failed.");

        return ISablierLockup(lockup);
    }


    /// @notice Deploys the lockup contract from an optimized source compiled with `--via-ir`.
    function deployOptimizedProtocol(
        address initialAdmin,
        uint256 maxCount
    )
        internal
        returns (ISablierLockup lockup_)
    {
        lockup_ = deployOptimizedLockup(initialAdmin, maxCount);
    }

    /// @dev Get the library placeholder which is a 34 character prefix of the hex encoding of the keccak256 hash of the
    /// fully qualified library name. It is a unique marker generated during compilation to represent the location in
    /// the bytecode where the address of the library should be inserted.
    function libraryPlaceholder(string memory libraryName) internal pure returns (string memory) {
        // Get the first 17 bytes of the hex encoding of the keccak256 hash of the library name.
        bytes memory placeholder = abi.encodePacked(bytes17(keccak256(abi.encodePacked(libraryName))));

        // Remove "0x" from the placeholder.
        string memory placeholderWithout0x = vm.replace(vm.toString(placeholder), "0x", "");

        // Append the expected prefix and suffix to the placeholder.
        return string.concat("__$", placeholderWithout0x, "$__");
    }
}
