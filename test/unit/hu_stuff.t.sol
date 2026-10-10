// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {HU_Stuff, HudState} from "../../src/doom/hu_stuff.sol";
import {HU_Lib, HuTextLine, HuSText} from "../../src/doom/hu_lib.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {RenderState} from "../../src/doom/r_state.sol";
import {Player} from "../../src/doom/p_game_state.sol";
import {M_BBox} from "../../src/doom/m_bbox.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface HudVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
    function etch(address, bytes calldata) external;
}

contract HudTestBase {
    HudVm constant vm = HudVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function fonts() internal view returns (bytes[] memory f) {
        f = new bytes[](63);
        for (uint256 i; i < 63; ++i) {
            f[i] = vm.readFileBinary(
                string.concat("test/fixtures/phase4_hud/STCFN0", vm.toString(i + 33), ".bin")
            );
        }
    }

    function freshVideo() internal pure returns (VideoState memory v) {
        v.screens[0] = new bytes(64000);
        v.screens[1] = new bytes(64000);
        bytes memory pattern = new bytes(768);
        for (uint256 i; i < 768; ++i) {
            pattern[i] = bytes1(uint8(i * 13));
        }
        for (uint256 s; s < 2; ++s) {
            bytes memory data = v.screens[s];
            for (uint256 row; row < 200; ++row) {
                uint256 offset = ((row * 71 + s * 41 + 19) * 197) & 255;
                uint256 pos = row * 320;
                // Both ranges cover 320 bytes within their live allocations.
                assembly ("memory-safe") {
                    mcopy(add(add(data, 32), pos), add(add(pattern, 32), offset), 320)
                }
            }
        }
        M_BBox.M_ClearBox(v.dirtybox);
    }

    function word(bytes memory b, uint256 p) internal pure returns (uint32 n) {
        for (uint256 i; i < 4; ++i) {
            n = (n << 8) | uint8(b[p + i]);
        }
    }

    function digest(bytes memory b, uint256 p) internal pure returns (bytes32 n) {
        require(p + 32 <= b.length);
        assembly ("memory-safe") { n := mload(add(add(b, 32), p)) }
    }

    function slice(bytes memory b, uint256 p, uint256 n) internal pure returns (bytes memory result) {
        require(p + n <= b.length);
        result = new bytes(n);
        // Exact source and destination ranges checked above.
        assembly ("memory-safe") { mcopy(add(result, 32), add(add(b, 32), p), n) }
    }

    function resourceFonts(bytes[] memory f) internal returns (ResourceView memory source) {
        source.lumps = new LumpDescriptor[](63);
        bytes memory blob;
        for (uint256 i; i < 63; ++i) {
            bytes8 name = bytes8(bytes(string.concat("STCFN0", vm.toString(i + 33))));
            source.lumps[i] = LumpDescriptor(name, uint32(blob.length), uint32(f[i].length));
            blob = bytes.concat(blob, f[i]);
        }
        source.byteLength = uint32(blob.length);
        source.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < source.chunks.length; ++i) {
            uint256 n = blob.length - i * 16384;
            if (n > 16384) n = 16384;
            address addr = address(uint160(0x1000 + i));
            source.chunks[i] = addr;
            vm.etch(addr, bytes.concat(hex"00", slice(blob, i * 16384, n)));
        }
    }
}

contract HUStuffTest is HudTestBase {
    function checkLine(HuTextLine memory l, bytes memory golden, uint256 p) private pure {
        require(l.x == int32(word(golden, p)) && l.y == int32(word(golden, p + 4)), "native line position");
        require(l.len == word(golden, p + 8) && l.needsupdate == word(golden, p + 12), "native line state");
        bytes memory text = l.text.length == 0 ? new bytes(81) : l.text;
        require(
            keccak256(text) == keccak256(slice(golden, p + 16, 81)),
            "native line buffer including NUL/stale tail"
        );
    }

    function runCase(bytes calldata trace, bytes[] memory f) external pure {
        HudState memory h;
        Player memory player;
        VideoState memory v = freshVideo();
        RenderState memory rs;
        rs.width = 320;
        rs.height = 168;
        HU_Stuff.HU_Start(h, f, 1, 1, 1);
        bool automap;
        bool show = true;
        uint32 eaten;
        uint256 p = 4;
        uint32 count = word(trace, 0);
        for (uint256 step; step < count; ++step) {
            uint32 op = word(trace, p);
            int32 a = int32(word(trace, p + 4));
            int32 b = int32(word(trace, p + 8));
            int32 c = int32(word(trace, p + 12));
            int32 d = int32(word(trace, p + 16));
            uint32 n = word(trace, p + 20);
            bytes memory text = slice(trace, p + 24, n);
            p += 24 + n;
            if (op == 0) HU_Stuff.HU_Start(h, f, a, b, c);
            if (op == 1) player.message = string(text);
            if (op == 2) {
                show = a != 0;
                h.message_dontfuckwithme = b != 0;
            }
            if (op == 3) {
                for (int32 i; i < a; ++i) {
                    HU_Stuff.HU_Ticker(h, player, show);
                }
            }
            if (op == 4 && HU_Stuff.HU_Responder(h, a, b)) ++eaten;
            if (op == 5) {
                automap = a != 0;
                HU_Stuff.HU_Drawer(h, v, automap);
            }
            if (op == 6) {
                rs.viewwindowx = a;
                rs.viewwindowy = b;
                rs.width = uint16(uint32(c));
                rs.height = uint16(uint32(d));
                HU_Stuff.HU_Erase(h, v, rs, automap);
            }
            if (op == 7) HU_Stuff.HU_Stop(h);
            if (op == 8) HU_Lib.HUlib_initSText(h.message, a, b, uint32(c), f, 33);
            if (op == 9) {
                HU_Lib.HUlib_addMessageToSText(
                    h.message, slice(text, 0, uint32(a)), slice(text, uint32(a), text.length - uint32(a))
                );
            }
            if (op == 10) {
                HU_Lib.HUlib_initTextLine(h.title, a, b, f, 33);
                for (uint256 i; i < text.length; ++i) {
                    HU_Lib.HUlib_addCharToTextLine(h.title, text[i]);
                }
                HU_Lib.HUlib_drawTextLine(h.title, v, c != 0);
            }
            if (op == 11) HU_Lib.HUlib_clearTextLine(h.title);
            if (op == 12) {
                for (int32 i; i < a; ++i) {
                    HU_Lib.HUlib_delCharFromTextLine(h.title);
                }
            }
            require(h.headsupactive == (word(trace, p) != 0), "native active");
            require(h.message.on == (word(trace, p + 4) != 0), "native on");
            require(h.message_dontfuckwithme == (word(trace, p + 8) != 0), "native force");
            require(h.message_nottobefuckedwith == (word(trace, p + 12) != 0), "native protected");
            require(
                h.message_counter == int32(word(trace, p + 16)) && eaten == word(trace, p + 20),
                "native timeout/response"
            );
            require(
                h.message.h == word(trace, p + 24) && h.message.cl == word(trace, p + 28)
                    && h.message.laston == (word(trace, p + 32) != 0),
                "native ring"
            );
            // C string contents end at NUL, while the Solidity player retains the complete bytes until consumed.
            bytes memory pending = bytes(player.message);
            uint256 len;
            while (len < pending.length && pending[len] != 0) ++len;
            require(
                len == word(trace, p + 36) && sha256(slice(pending, 0, len)) == digest(trace, p + 40),
                "native pending player message"
            );
            for (uint256 i; i < 4; ++i) {
                checkLine(h.message.lines[i], trace, p + 72 + i * 97);
            }
            checkLine(h.title, trace, p + 460);
            for (uint256 i; i < 4; ++i) {
                require(v.dirtybox[i] == int32(word(trace, p + 557 + i * 4)), "native dirty box");
            }
            require(sha256(v.screens[0]) == digest(trace, p + 573), "native full framebuffer");
            p += 605;
        }
        require(p == trace.length, "exact trace length");
    }

    function nativeRange(uint256 begin, uint256 end) private {
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_hud/cases.bin");
        bytes[] memory f = fonts();
        uint256 pos = 4;
        uint32 cases = word(data, 0);
        require(cases == 209, "native case count");
        for (uint256 k; k < cases; ++k) {
            uint256 start = pos;
            uint32 steps = word(data, pos);
            pos += 4;
            for (uint256 j; j < steps; ++j) {
                uint32 n = word(data, pos + 20);
                pos += 24 + n + 605;
            }
            if (k >= begin && k < end) this.runCase(slice(data, start, pos - start), f);
        }
        require(pos == data.length, "fixture length");
    }

    function testNativeMessageTimingVisibilityAndWidgets() public {
        nativeRange(0, 17);
    }

    function testNativeEveryWadGlyph() public {
        nativeRange(17, 80);
    }

    function testNativeTitlesAndErasure() public {
        nativeRange(80, 165);
    }

    function testNativeGameplayProducedMessages() public {
        nativeRange(165, 209);
    }

    function testOriginalWadFontResourceLoading() public {
        bytes[] memory f = fonts();
        ResourceView memory source = resourceFonts(f);
        bytes[] memory loaded = HU_Stuff.HU_Init(source);
        require(loaded.length == 63);
        for (uint256 i; i < 63; ++i) {
            require(sha256(loaded[i]) == sha256(f[i]), "STCFN identity");
        }
    }

    function invalidTitle(int32 mode, int32 ep, int32 map) external pure {
        HU_Stuff.mapTitle(mode, ep, map);
    }

    function testUndefinedMapIndexesRejected() public {
        (bool ok, bytes memory err) = address(this).call(abi.encodeCall(this.invalidTitle, (1, 0, 1)));
        require(!ok && bytes4(err) == HU_Stuff.InvalidMapTitle.selector);
        (ok, err) = address(this).call(abi.encodeCall(this.invalidTitle, (2, 1, 33)));
        require(!ok && bytes4(err) == HU_Stuff.InvalidMapTitle.selector);
    }
}
