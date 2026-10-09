// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Ordinary CREATE of a bounded immutable chunk, with a STOP prefix.
/// @dev Deployment is static resource preparation; no gameplay or visibility output.
contract ResourceStore {
    constructor(bytes memory payload) {
        require(payload.length <= 16384, "resource chunk >16KiB");
        bytes memory runtime = bytes.concat(hex"00", payload);
        // The complete returned region is the allocated bytes payload (length excludes header).
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}
