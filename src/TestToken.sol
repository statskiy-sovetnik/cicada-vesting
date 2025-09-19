// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title TestToken
/// @notice Simple test contract to verify deployment configuration
contract TestToken is ERC20 {
    /// @notice Maximum supply of tokens
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18;

    /// @notice Block number when contract was deployed
    uint256 public immutable DEPLOYED_AT_BLOCK;

    constructor() ERC20("TestToken", "TEST") {
        DEPLOYED_AT_BLOCK = block.number;

        // Mint initial supply to deployer
        _mint(msg.sender, 100_000 * 10**18);
    }

    /// @notice Get contract info
    /// @return deployedBlock Block number when deployed
    function getDeployedBlock() external view returns (uint256 deployedBlock) {
        return DEPLOYED_AT_BLOCK;
    }
}