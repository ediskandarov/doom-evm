// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Phase 1 placement experiment; no original C counterpart or renderer adapter.
contract StorageResourceFixture {
    bytes private data;

    constructor(bytes memory payload) {
        data = payload;
    }

    function read(uint256 offset, uint256 length) public view returns (bytes memory result) {
        require(offset <= data.length && length <= data.length - offset, "bounds");
        result = new bytes(length);
        for (uint256 i; i < length; ++i) {
            result[i] = data[offset + i];
        }
    }

    event Sample(bytes32 digest);

    function sample(uint256 offset, uint256 length) external {
        emit Sample(sha256(read(offset, length)));
    }
}

/// @dev Deployed runtime is STOP followed by immutable bytes. Ordinary CREATE, no setCode.
contract ResourceBytesFixture {
    constructor(bytes memory payload) {
        bytes memory runtime = bytes.concat(hex"00", payload);
        // The return range is precisely the allocated bytes array, excluding its length word.
        assembly ("memory-safe") {
            return(add(runtime, 32), mload(runtime))
        }
    }
}

contract CodeResourceFixture {
    address public immutable source;
    uint256 public immutable byteLength;

    constructor(bytes memory payload) {
        source = address(new ResourceBytesFixture(payload));
        byteLength = payload.length;
    }

    function read(uint256 offset, uint256 length) public view returns (bytes memory result) {
        require(offset <= byteLength && length <= byteLength - offset, "bounds");
        result = new bytes(length);
        address target = source;
        // Writes exactly length bytes into a freshly allocated array. Source byte 0 is STOP.
        assembly ("memory-safe") {
            extcodecopy(target, add(result, 32), add(offset, 1), length)
        }
    }

    event Sample(bytes32 digest);

    function sample(uint256 offset, uint256 length) external {
        emit Sample(sha256(read(offset, length)));
    }
}
