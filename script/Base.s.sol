// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable no-console
pragma solidity >=0.8.22 <0.9.0;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { console2 } from "forge-std/src/console2.sol";
import { Script } from "forge-std/src/Script.sol";
import { stdJson } from "forge-std/src/StdJson.sol";

contract BaseScript is Script {
    using Strings for uint256;
    using stdJson for string;

    /// @dev The default value for `maxCountMap`.
    uint256 internal constant DEFAULT_MAX_COUNT = 500;

    /// @dev The address of the default Sablier admin.
    address internal constant DEFAULT_SABLIER_ADMIN = address(0);

    /// @dev The salt used for deterministic deployments.
    bytes32 internal immutable SALT;

    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Admin address mapped by the chain Id.
    mapping(uint256 chainId => address admin) internal adminMap;

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $EOA is not defined.
    string internal mnemonic;

    /// @dev Maximum count for segments and tranches mapped by the chain Id.
    mapping(uint256 chainId => uint256 count) internal maxCountMap;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $EOA is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $EOA is to specify the broadcaster key and its address via the command line.
    constructor() {
        address from = vm.envOr({ name: "EOA", defaultValue: address(0) });
        if (from != address(0)) {
            broadcaster = from;
        } else {
            mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
            (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
        }

        // Construct the salt for deterministic deployments.
        SALT = constructCreate2Salt();

        // Populate the admin map.
        populateAdminMap();

        // Populate the max count map for segments and tranches.
        populateMaxCountMap();

        // If there is no admin set for a specific chain, use the default Sablier admin.
        if (adminMap[block.chainid] == address(0)) {
            adminMap[block.chainid] = DEFAULT_SABLIER_ADMIN;
        }

        // If there is no maximum value set for a specific chain, use the default value.
        if (maxCountMap[block.chainid] == 0) {
            maxCountMap[block.chainid] = DEFAULT_MAX_COUNT;
        }
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    /// @dev The presence of the salt instructs Forge to deploy contracts via this deterministic CREATE2 factory:
    /// https://github.com/Arachnid/deterministic-deployment-proxy
    ///
    /// Notes:
    /// - The salt format is "ChainID <chainid>, Version <version>".
    function constructCreate2Salt() public view returns (bytes32) {
        string memory chainId = block.chainid.toString();
        string memory version = getVersion();
        string memory create2Salt = string.concat("ChainID ", chainId, ", Version ", version);
        console2.log("The CREATE2 salt is \"%s\"", create2Salt);
        return bytes32(abi.encodePacked(create2Salt));
    }

    /// @dev The version is obtained from `package.json`.
    function getVersion() internal view returns (string memory) {
        string memory json = vm.readFile("package.json");
        return json.readString(".version");
    }

    /// @dev Populates the admin map. The reason the chain IDs configured for the admin map do not match the other
    /// maps is that we only have multisigs for the chains listed below, otherwise, the default admin is used.​
    function populateAdminMap() internal {
        adminMap[202105] = address(0); // Duckchain testnet
        adminMap[5545] = address(0); // Duckchain mainnet
    }

    /// @dev Updates max values for segments and tranches. Values can be updated using the `update-counts.sh` script.
    function populateMaxCountMap() internal {
        // forgefmt: disable-start

        maxCountMap[202105] = 500; // Duckchain testnet chain ID
        maxCountMap[5545] = 500; // Duckchain mainnet chain ID

        // forgefmt: disable-end
    }
}
