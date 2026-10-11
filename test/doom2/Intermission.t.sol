// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {WiState, WiStart, WiInput, WiGraphics} from "../../src/doom/wi_stuff_types.sol";
import {WI_Stuff as WI} from "../../src/doom/wi_stuff.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";
import {IntermissionFixture as F} from "../../src/support/IntermissionFixture.sol";
import {IntermissionProbe} from "../../src/support/IntermissionProbe.sol";

interface WiVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function prank(address) external;
}

contract Doom2CommercialIntermissionTest {
    WiVm constant vm = WiVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ResourceView[4] internal sources;
    bool[4] internal loaded;

    function slice(bytes memory b, uint256 offset, uint256 length) private pure returns (bytes memory out) {
        require(offset + length <= b.length);
        out = new bytes(length);
        // Complete bounded source/destination slices; MCOPY writes no padding/header bytes.
        assembly ("memory-safe") { mcopy(add(out, 32), add(add(b, 32), offset), length) }
    }

    function resources(uint256 profile) private returns (ResourceView memory r) {
        if (loaded[profile]) return sources[profile];
        bytes memory b = vm.readFileBinary(
            string.concat("artifacts/local/wad/doom2-ui/intermission/assets-", vm.toString(profile), ".bin")
        );
        uint256 count = uint32(F.word(b, 0));
        uint256 base = 4 + count * 16;
        r.byteLength = uint32(b.length - base);
        r.lumps = new LumpDescriptor[](count);
        for (uint256 i; i < count; ++i) {
            bytes8 name;
            uint256 cursor = 4 + i * 16;
            assembly ("memory-safe") { name := mload(add(add(b, 32), cursor)) }
            r.lumps[i] = LumpDescriptor(name, uint32(F.word(b, cursor + 8)), uint32(F.word(b, cursor + 12)));
        }
        r.chunks = new address[]((r.byteLength + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 n = r.byteLength - i * 16384;
            if (n > 16384) n = 16384;
            r.chunks[i] = address(new ResourceStore(slice(b, base + i * 16384, n)));
        }
        loaded[profile] = true;
        sources[profile] = r;
    }

    function check(bytes memory expected, uint256 i, WiState memory s, WiInput memory p, VideoState memory v)
        private
        pure
    {
        uint256 pos = i * 532;
        require(
            sha256(F.stateBytes(s, p)) == sha256(slice(expected, pos, 452)),
            "original C state/RNG/latched input"
        );
        require(
            sha256(abi.encodePacked(v.dirtybox[0], v.dirtybox[1], v.dirtybox[2], v.dirtybox[3]))
                == sha256(slice(expected, pos + 452, 16)),
            "original dirtybox"
        );
        bytes32 frame;
        bytes32 bg;
        assembly ("memory-safe") {
            frame := mload(add(add(expected, 32), add(pos, 468)))
            bg := mload(add(add(expected, 32), add(pos, 500)))
        }
        require(sha256(v.screens[0]) == frame, "all 64000 original indexed pixels");
        require(sha256(v.screens[1]) == bg, "original background backing");
    }

    function nativeCase(uint256 index) private {
        string memory prefix = string.concat("artifacts/local/wad/doom2-ui/intermission/", vm.toString(index));
        bytes memory data = vm.readFileBinary(string.concat(prefix, ".bin"));
        bytes memory expected = vm.readFileBinary(string.concat(prefix, ".expected.bin"));
        ResourceView memory source = resources(uint32(F.word(data, 60)));
        WiState memory s;
        WiInput memory p;
        WiGraphics memory a;
        VideoState memory v;
        F.start(data, s, p, a, v, source);
        check(expected, 0, s, p, v);
        uint256 count = uint32(F.word(data, 64));
        require(expected.length == (count + 1) * 532);
        for (uint256 i; i < count; ++i) {
            int32[5] memory q;
            for (uint256 j; j < 5; ++j) {
                q[j] = F.word(data, 68 + i * 20 + j * 4);
            }
            F.action(q, s, p, a, v, source);
            check(expected, i + 1, s, p, v);
        }
    }

    function testOriginalCommercialTitles1Through6() public { for(uint256 i=0;i<6;++i)nativeCase(i); }
    function testOriginalCommercialTitles7Through12() public { for(uint256 i=6;i<12;++i)nativeCase(i); }
    function testOriginalCommercialTitles13Through18() public { for(uint256 i=12;i<18;++i)nativeCase(i); }
    function testOriginalCommercialTitles19Through24() public { for(uint256 i=18;i<24;++i)nativeCase(i); }
    function testOriginalCommercialTitles25Through30() public { for(uint256 i=24;i<30;++i)nativeCase(i); }
    function testOriginalCommercialTitles31Through36() public { for(uint256 i=30;i<36;++i)nativeCase(i); }
}
