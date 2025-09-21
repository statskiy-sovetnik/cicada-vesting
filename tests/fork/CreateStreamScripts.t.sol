// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22 <0.9.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISablierLockup } from "src/interfaces/ISablierLockup.sol";

import { CreateStream_D90 } from "script/CreateStream_D90.s.sol";
import { CreateStream_D120 } from "script/CreateStream_D120.s.sol";
import { CreateStream_D150 } from "script/CreateStream_D150.s.sol";
import { CreateStream_D180 } from "script/CreateStream_D180.s.sol";

import { Fork_Test } from "./Fork.t.sol";
import { console2 } from "forge-std/src/console2.sol";

contract CreateStreamScripts_Fork_Test is Fork_Test(IERC20(0xdA65892eA771d3268610337E9964D916028B7dAD)) {
    /*//////////////////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address private deployer;
    uint40 private immutable START_TIME = uint40(block.timestamp + 1 days);

    CreateStream_D90 private streamD90;
    CreateStream_D120 private streamD120;
    CreateStream_D150 private streamD150;
    CreateStream_D180 private streamD180;

    /*//////////////////////////////////////////////////////////////////////////
                                    SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Stop any active prank from the base class
        vm.stopPrank();

        // Get private key from environment
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);

        // Label the deployer address
        vm.label(deployer, "Script Deployer");

        // Deploy the script contracts
        streamD90 = new CreateStream_D90();
        streamD120 = new CreateStream_D120();
        streamD150 = new CreateStream_D150();
        streamD180 = new CreateStream_D180();

        // Label the script contracts
        vm.label(address(streamD90), "CreateStream_D90");
        vm.label(address(streamD120), "CreateStream_D120");
        vm.label(address(streamD150), "CreateStream_D150");
        vm.label(address(streamD180), "CreateStream_D180");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                        TESTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Test running all CreateStream scripts sequentially
    function test_RunAllCreateStreamScripts() external {
        // Get current stream count before running scripts
        uint256 initialStreamCount = lockup.nextStreamId();

        // Give deployer some ETH for gas
        vm.deal(deployer, 10 ether);

        // Run D90 script
        console2.log("Running CreateStream_D90 script...");
        streamD90.run(START_TIME);

        // Run D120 script
        console2.log("Running CreateStream_D120 script...");
        streamD120.run(START_TIME);

        // Run D150 script
        console2.log("Running CreateStream_D150 script...");
        streamD150.run(START_TIME);

        // Run D180 script
        console2.log("Running CreateStream_D180 script...");
        streamD180.run(START_TIME);

        // Verify that 4 new streams were created
        uint256 finalStreamCount = lockup.nextStreamId();
        assertEq(finalStreamCount, initialStreamCount + 4, "Should have created 4 new streams");

        console2.log("Successfully created", finalStreamCount - initialStreamCount, "streams");
        console2.log("Stream IDs:", initialStreamCount, "to", finalStreamCount - 1);
    }

    /// @dev Test individual script execution - D90
    function test_CreateStreamD90() external {
        uint256 initialStreamCount = lockup.nextStreamId();

        vm.deal(deployer, 10 ether);

        streamD90.run(START_TIME);

        uint256 finalStreamCount = lockup.nextStreamId();
        assertEq(finalStreamCount, initialStreamCount + 1, "Should have created 1 stream");
    }

    /// @dev Test individual script execution - D120
    function test_CreateStreamD120() external {
        uint256 initialStreamCount = lockup.nextStreamId();

        vm.deal(deployer, 10 ether);

        streamD120.run(START_TIME);

        uint256 finalStreamCount = lockup.nextStreamId();
        assertEq(finalStreamCount, initialStreamCount + 1, "Should have created 1 stream");
    }

    /// @dev Test individual script execution - D150
    function test_CreateStreamD150() external {
        uint256 initialStreamCount = lockup.nextStreamId();

        vm.deal(deployer, 10 ether);

        streamD150.run(START_TIME);

        uint256 finalStreamCount = lockup.nextStreamId();
        assertEq(finalStreamCount, initialStreamCount + 1, "Should have created 1 stream");
    }

    /// @dev Test individual script execution - D180
    function test_CreateStreamD180() external {
        uint256 initialStreamCount = lockup.nextStreamId();

        vm.deal(deployer, 10 ether);

        streamD180.run(START_TIME);

        uint256 finalStreamCount = lockup.nextStreamId();
        assertEq(finalStreamCount, initialStreamCount + 1, "Should have created 1 stream");
    }

    /// @dev Test that scripts create cliff-only streams with correct parameters
    function test_VerifyStreamParameters() external {
        uint256 initialStreamCount = lockup.nextStreamId();

        vm.deal(deployer, 10 ether);

        // Run D90 script to create a stream
        streamD90.run(START_TIME);

        // Get the created stream ID
        uint256 streamId = initialStreamCount;

        // Verify stream exists
        assertTrue(lockup.isStream(streamId), "Stream should exist");

        // Get stream info using individual methods
        address recipient = lockup.getRecipient(streamId);
        uint128 depositAmount = lockup.getDepositedAmount(streamId);
        IERC20 token = lockup.getUnderlyingToken(streamId);
        uint40 startTime = lockup.getStartTime(streamId);
        uint40 endTime = lockup.getEndTime(streamId);

        // Verify basic stream properties
        assertTrue(depositAmount > 0, "Stream should have deposit amount");
        assertTrue(recipient != address(0), "Recipient should not be zero address");
        assertTrue(address(token) != address(0), "Token should not be zero address");
        assertTrue(startTime > 0, "Start time should be set");
        assertTrue(endTime > startTime, "End time should be after start time");

        // Get token name and symbol
        string memory tokenName = IERC20Metadata(address(token)).name();
        string memory tokenSymbol = IERC20Metadata(address(token)).symbol();

        console2.log("Stream verified:");
        console2.log("  ID:", streamId);
        console2.log("  Recipient:", recipient);
        console2.log("  Amount:", depositAmount);
        console2.log("  Token:", address(token));
        console2.log("  Token Name:", tokenName);
        console2.log("  Token Symbol:", tokenSymbol);
        console2.log("  Start:", startTime);
        console2.log("  End:", endTime);
    }
}