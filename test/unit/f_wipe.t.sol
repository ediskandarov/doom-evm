// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {F_Wipe as W, WipeState} from "../../src/doom/f_wipe.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";

interface WipeVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
}

contract WipeStorageHost {
    WipeState private saved;

    function start() external {
        WipeState memory s;
        VideoState memory v;
        v.screens[0] = new bytes(64000);
        W.wipe_StartScreen(s, v);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = 0x49;
        }
        W.wipe_EndScreen(s, v);
        saved = s;
    }

    function step(uint32 ticks, bool reject) external returns (bool done) {
        WipeState memory s = saved;
        VideoState memory v;
        done = W.wipe_ScreenWipe(s, v, ticks);
        saved = s;
        require(!reject, "intentional rollback after writes");
    }

    function digest() external view returns (bytes32) {
        return sha256(abi.encode(saved));
    }
}

contract WipeTest {
    WipeVm constant vm = WipeVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function word(bytes memory b, uint256 at) private pure returns (uint32 v) {
        for (uint256 i; i < 4; ++i) {
            v = (v << 8) | uint8(b[at + i]);
        }
    }

    function hash(bytes memory b, uint256 at) private pure returns (bytes32 h) {
        assembly ("memory-safe") { h := mload(add(add(b, 32), at)) }
    }

    function compare(string memory file, uint32 seed, uint32 ticks) private view {
        bytes memory e = vm.readFileBinary(string.concat("test/fixtures/full_wipe/", file, ".bin"));
        WipeState memory s;
        s.rndindex = seed;
        VideoState memory v;
        v.screens[0] = new bytes(64000);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = bytes1(uint8((i * 7 + i / 320) % 256));
        }
        W.wipe_StartScreen(s, v);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = bytes1(uint8((i * 11 + 73 + i / 160) % 256));
        }
        W.wipe_EndScreen(s, v);
        require(sha256(v.screens[0]) == sha256(s.wipe_scr_start), "restored start screen");
        for (uint256 at; at < e.length; at += 72) {
            bool done = W.wipe_ScreenWipe(s, v, ticks);
            require(done == (word(e, at) != 0), "native completion timing");
            require(s.rndindex == word(e, at + 4), "320 original random calls");
            require(sha256(abi.encode(s.y)) == hash(e, at + 8), "all native column positions");
            require(sha256(v.screens[0]) == hash(e, at + 40), "64000 native pixels");
            require(!done || at + 72 == e.length, "no early completion");
            require(
                v.dirtybox[0] == 199 && v.dirtybox[1] == 0 && v.dirtybox[2] == 0 && v.dirtybox[3] == 319,
                "dirtybox"
            );
        }
    }

    function testNativeSeed0() external view {
        compare("0-1", 0, 1);
    }

    function testNativeSeed1() external view {
        compare("1-1", 1, 1);
    }

    function testNativeSeed127() external view {
        compare("127-1", 127, 1);
    }

    function testNativeSeed255() external view {
        compare("255-1", 255, 1);
    }

    function testNativeThreeTicks() external view {
        compare("0-3", 0, 3);
    }

    function testNativeSevenTicks() external view {
        compare("127-7", 127, 7);
    }

    function testNativeLargeBatchCompletionDelay() external view {
        compare("255-200", 255, 200);
    }

    function testStoragePersistenceAndRollback() external {
        WipeStorageHost h = new WipeStorageHost();
        h.start();
        bytes32 before = h.digest();
        h.step(1, false);
        bytes32 advanced = h.digest();
        require(before != advanced, "persistent progress");
        (bool ok,) = address(h).call(abi.encodeCall(h.step, (1, true)));
        require(!ok, "rollback rejected");
        require(h.digest() == advanced, "all wipe state rolled back");
        (ok,) = address(h).call(abi.encodeCall(h.step, (0, false)));
        require(!ok, "zero ticks rejected");
        require(h.digest() == advanced, "invalid call preserves state");
    }
}
