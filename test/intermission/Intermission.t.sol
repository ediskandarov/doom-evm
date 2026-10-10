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

contract IntermissionTest {
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
            string.concat("test/fixtures/phase4_intermission/assets-", vm.toString(profile), ".bin")
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
        string memory prefix = string.concat("test/fixtures/phase4_intermission/", vm.toString(index));
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

    function testNativeNaturalCountingEveryTicAndTimeout() public {
        nativeCase(0);
    }

    function testNativeZeroTotalsAllSupportedModes() public {
        for (uint256 i = 1; i < 4; ++i) {
            nativeCase(i);
        }
    }

    function testNativeInputSecretRepeatAndCounterQuirks() public {
        for (uint256 i = 4; i < 12; ++i) {
            nativeCase(i);
        }
    }

    function testNativeEveryFinishedTitle() public {
        for (uint256 i = 12; i < 21; ++i) {
            nativeCase(i);
        }
    }

    function testNativeEveryEnteringTitleAndNode() public {
        for (uint256 i = 21; i < 30; ++i) {
            nativeCase(i);
        }
    }

    function testNativeNumericFormattingAndCandidateFallbacks() public {
        for (uint256 i = 30; i < 34; ++i) {
            nativeCase(i);
        }
    }

    function testNativeStateAcrossSeparateStorageCallsAndRollback() public {
        ResourceView memory source = resources(0);
        IntermissionProbe probe = new IntermissionProbe(source);
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_intermission/4.bin");
        bytes memory expected = vm.readFileBinary("test/fixtures/phase4_intermission/4.expected.bin");
        probe.begin(slice(data, 0, 64), 1);
        (bytes memory state,) = probe.snapshot();
        require(sha256(state) == sha256(slice(expected, 0, 452)));
        uint256 count = uint32(F.word(data, 64));
        for (uint256 i; i < count; ++i) {
            int32[5] memory q;
            for (uint256 j; j < 5; ++j) {
                q[j] = F.word(data, 68 + i * 20 + j * 4);
            }
            probe.act(q, uint32(i + 2), q[3] != 0);
            (state,) = probe.snapshot();
            require(sha256(state) == sha256(slice(expected, (i + 1) * 532, 452)), "storage native state");
        }
        (bytes memory beforeState, bytes32 beforePixels) = probe.snapshot();
        uint64 frames = probe.frameId();
        uint32 seq = probe.inputSeq();
        int32[5] memory extra = [int32(0), 1, 0, 0, 0];
        (bool ok,) = address(probe).call(abi.encodeCall(probe.act, (extra, seq + 1, false)));
        require(!ok, "post-completion ticker rejected");
        int32[5] memory draw = [int32(1), 0, 0, 0, 0];
        (ok,) = address(probe).call(abi.encodeCall(probe.act, (draw, seq + 1, true)));
        require(!ok, "native post-free drawer excluded");
        bytes32 pixelsHash;
        (state, pixelsHash) = probe.snapshot();
        require(keccak256(state) == keccak256(beforeState) && pixelsHash == beforePixels);
        require(probe.inputSeq() == seq && probe.frameId() == frames, "rollback sequences");
    }

    function testFrameEventContainsComputedNativePixelsAndSourceAlias() public {
        IntermissionProbe probe = new IntermissionProbe(resources(1));
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_intermission/6.bin");
        bytes memory nativePixels = vm.readFileBinary("test/fixtures/phase4_intermission/6.pixels");
        vm.recordLogs();
        probe.run(data, 1);
        WiVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2 && logs[1].emitter == address(probe));
        (uint16 width, uint16 height, bytes memory pixels) = abi.decode(logs[1].data, (uint16, uint16, bytes));
        require(width == 320 && height == 200 && pixels.length == 64000);
        require(keccak256(pixels) == keccak256(nativePixels), "exact native full frame");
    }

    function invalid(uint256 kind) external pure {
        WiState memory s;
        WiStart memory w;
        WiInput memory p;
        p.playeringame[0] = true;
        p.gamemode = 3;
        if (kind == 0) w.epsd = 1;
        if (kind == 1) w.pnum = 1;
        if (kind == 2) w.next = 9;
        if (kind == 3) w.maxkills = -1;
        if (kind == 4) w.plyr[0].skills = type(int32).max;
        if (kind == 5) w.plyr[0].stime = -1;
        WI.WI_initVariables(s, w);
        if (kind == 6) p.gamemode = 2;
        if (kind == 7) p.playeringame[1] = true;
        WI.WI_initStats(s, p);
        if (kind == 8) p.rndindex = 256;
        if (kind == 9) s.bcnt = type(int32).max;
        WI.WI_Ticker(s, p);
    }

    function testUnsupportedAndUndefinedDomainsAreExplicit() public {
        for (uint256 i; i < 10; ++i) {
            (bool ok, bytes memory errorData) = address(this).call(abi.encodeCall(this.invalid, (i)));
            require(
                !ok
                    && (bytes4(errorData) == WI.UnsupportedIntermission.selector
                        || bytes4(errorData) == WI.UndefinedNativeDomain.selector),
                "bounded original domain"
            );
        }
    }

    function testStartNormalizesCanonicalSnapshotWithoutResettingPointerOrLatches() public pure {
        WiState memory s;
        s.snl_pointeron = true;
        WiStart memory w;
        WiInput memory p;
        p.playeringame[0] = true;
        p.gamemode = 3;
        p.attackdown[0] = 1;
        p.usedown[0] = 1;
        WI.WI_initVariables(s, w);
        WI.WI_initStats(s, p);
        require(w.maxkills == 1 && w.maxitems == 1 && w.maxsecret == 1, "original wbs alias");
        require(s.snl_pointeron && p.attackdown[0] == 1 && p.usedown[0] == 1, "original statics");
        require(p.rndindex == 10 && s.cnt_time == -1 && s.cnt_kills[0] == -1);
        require(!WI.WI_Responder(0, 13), "original responder does not advance");
    }

    function testMalformedSourceAndUnauthorizedCallsRollBack() public {
        IntermissionProbe probe = new IntermissionProbe(resources(0));
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_intermission/4.bin");
        (bool ok,) = address(probe).call(abi.encodeCall(probe.run, (hex"00", uint32(1))));
        require(!ok);
        vm.prank(address(99));
        (ok,) = address(probe).call(abi.encodeCall(probe.run, (data, uint32(1))));
        require(!ok);
        require(probe.inputSeq() == 0 && probe.frameId() == 0);
        probe.run(data, 1);
        (bytes memory beforeState, bytes32 beforePixels) = probe.snapshot();
        (ok,) = address(probe).call(abi.encodeCall(probe.run, (data, uint32(1))));
        require(!ok);
        (bytes memory afterState, bytes32 afterPixels) = probe.snapshot();
        require(keccak256(beforeState) == keccak256(afterState) && beforePixels == afterPixels);
    }

    function testMalformedBackgroundResourceRejectsBeforePublishingState() public {
        ResourceView memory bad = resources(0);
        bad.lumps[0].length = 1; // Truncate the actual WIMAP0 patch header, keep immutable source code.
        IntermissionProbe probe = new IntermissionProbe(bad);
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_intermission/4.bin");
        vm.recordLogs();
        (bool ok, bytes memory errorData) = address(probe).call(abi.encodeCall(probe.run, (data, uint32(1))));
        require(
            !ok && bytes4(errorData) == bytes4(keccak256("MalformedPatch()")), "original resource boundary"
        );
        require(vm.getRecordedLogs().length == 0 && probe.inputSeq() == 0 && probe.frameId() == 0);
        (bytes memory state,) = probe.snapshot();
        require(F.word(state, 93 * 4) == 0, "failed start does not persist initialized state");
    }
}
