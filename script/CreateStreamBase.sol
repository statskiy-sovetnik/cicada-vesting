// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/src/Script.sol";

interface IERC20 {
    function approve(address spender, uint256 value) external returns (bool);
    function decimals() external view returns (uint8);
}

interface ISablierLockup {
    struct Timestamps { uint40 start; uint40 end; }
    struct Broker { address account; uint256 fee; }
    struct CreateWithTimestamps {
        address sender;
        address recipient;
        uint128 totalAmount;
        address token;
        bool transferable;
        Timestamps timestamps;
        string shape;
        Broker broker;
    }
    struct UnlockAmounts { uint128 start; uint128 cliff; }

    function createWithTimestampsLL(
        CreateWithTimestamps calldata params,
        UnlockAmounts calldata unlockAmounts,
        uint40 cliffTime
    ) external payable returns (uint256 streamId);
}

abstract contract CreateStreamBase is Script {
    address constant LOCKUP_ADDR    = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa; // TODO change address
    address constant TOKEN_ADDR     = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB; // TODO change address
    address constant RECIPIENT      = 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC; // TODO change address
    address constant SENDER         = 0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd; // TODO change address
    bool    constant TRANSFERABLE   = true;
    address constant BROKER_ACCOUNT = address(0);
    uint256 constant BROKER_FEE     = 0;

    uint128 constant AMOUNT         = 0; // TODO: set 20% tranche
    uint40  constant CLIFF_DAYS     = 90;

    function run(uint40 t0) external {
        uint40 startTime = t0;
        uint40 cliff     = t0 + _cliffDays() * 1 days;
        uint40 endTime   = cliff + 1;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        require(IERC20(TOKEN_ADDR).approve(LOCKUP_ADDR, _cliffUnlockAmount()), "approve failed");

        ISablierLockup.CreateWithTimestamps memory P = ISablierLockup.CreateWithTimestamps({
            sender:       SENDER,
            recipient:    RECIPIENT,
            totalAmount:  _cliffUnlockAmount(),
            token:        TOKEN_ADDR,
            transferable: TRANSFERABLE,
            timestamps:   ISablierLockup.Timestamps({ start: startTime, end: endTime }),
            shape:        "",
            broker:       ISablierLockup.Broker({ account: BROKER_ACCOUNT, fee: BROKER_FEE })
        });

        ISablierLockup.UnlockAmounts memory U = ISablierLockup.UnlockAmounts({
            start: 0,
            cliff: _cliffUnlockAmount()
        });

        uint256 id = ISablierLockup(LOCKUP_ADDR).createWithTimestampsLL(P, U, cliff);

        vm.stopBroadcast();

        console2.log("D90 streamId:", id);
        console2.log("Start:", startTime);
        console2.log("Cliff:", cliff, "End:", endTime);
    }

    function _cliffDays() internal virtual returns (uint40);

    function _cliffUnlockAmount() internal virtual returns (uint128);
}