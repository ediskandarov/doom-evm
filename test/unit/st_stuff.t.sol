// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ST_Stuff as ST, STState, STGraphics} from "../../src/doom/st_stuff.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {V_Video} from "../../src/doom/v_video.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {GameState, GameDefinitions, Player, Mobj, GameConst} from "../../src/doom/p_game_state.sol";

interface StatusVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
}

contract STStuffTest {
    StatusVm constant vm = StatusVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error StateMismatch(uint256 row, uint256 field, int32 expected, int32 actual);
    error PixelMismatch(uint256 row, uint256 screen, bytes32 expected, bytes32 actual);

    function source() internal returns (ResourceView memory r) {
        bytes memory blob = vm.readFileBinary("test/fixtures/phase4_statusbar/resources.bin");
        bytes memory dir = vm.readFileBinary("test/fixtures/phase4_statusbar/directory.bin");
        r.byteLength = uint32(blob.length);
        r.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 n = blob.length - i * 16384;
            if (n > 16384) n = 16384;
            bytes memory code = new bytes(n + 1);
            for (uint256 j; j < n; ++j) {
                code[j + 1] = blob[i * 16384 + j];
            }
            r.chunks[i] = address(uint160(0x420000 + i));
            vm.etch(r.chunks[i], code);
        }
        r.lumps = new LumpDescriptor[](dir.length / 16);
        for (uint256 i; i < r.lumps.length; ++i) {
            bytes8 name;
            uint256 pos = i * 16;
            assembly ("memory-safe") { name := mload(add(add(dir, 32), pos)) }
            r.lumps[i] = LumpDescriptor(name, le32(dir, pos + 8), le32(dir, pos + 12));
        }
    }

    function le32(bytes memory b, uint256 p) internal pure returns (uint32 n) {
        for (uint256 i; i < 4; ++i) {
            n |= uint32(uint8(b[p + i])) << uint32(i * 8);
        }
    }

    function be32(bytes memory b, uint256 p) internal pure returns (int32 n) {
        uint32 v;
        for (uint256 i; i < 4; ++i) {
            v = (v << 8) | uint8(b[p + i]);
        }
        return int32(v);
    }

    function digest(bytes memory b, uint256 pos) internal pure returns (bytes32 h) {
        assembly ("memory-safe") { h := mload(add(add(b, 32), pos)) }
    }

    function definitions() internal pure returns (GameDefinitions memory d) {
        int32[9] memory ammo = [int32(5), 0, 1, 0, 3, 2, 2, 5, 1];
        for (uint256 i; i < 9; ++i) {
            d.weaponinfo[i].ammo = ammo[i];
        }
    }

    function input(GameState memory g, STState memory s, int32[36] memory a) internal pure {
        Player memory p = g.players[0];
        p.mo = 0;
        p.health = a[1];
        p.armorpoints = a[2];
        p.readyweapon = uint32(a[3]);
        for (uint256 i; i < 4; ++i) {
            p.ammo[i] = a[4 + i];
            p.maxammo[i] = a[8 + i];
            p.frags[i] = a[31 + i];
        }
        for (uint256 i; i < 9; ++i) {
            p.weaponowned[i] = (uint32(a[12]) >> i) & 1 != 0;
        }
        for (uint256 i; i < 6; ++i) {
            p.cards[i] = (uint32(a[13]) >> i) & 1 != 0;
        }
        p.damagecount = a[14];
        p.bonuscount = a[15];
        p.powers[1] = a[16];
        p.powers[3] = a[17];
        p.powers[0] = a[18];
        p.cheats = a[19];
        p.attackdown = a[20];
        p.attacker = a[21] == 0 ? GameConst.NULL : a[21] == 1 ? 0 : 1;
        g.mobjs[1].x = a[22];
        g.mobjs[1].y = a[23];
        g.mobjs[0].angle = uint32(a[24]);
        g.deathmatch = a[28];
        g.netgame = a[29] != 0;
        s.usegamma = uint8(uint32(a[30]));
    }

    function snapshot(STState memory s, GameState memory g, GameDefinitions memory d)
        internal
        pure
        returns (int32[24] memory x)
    {
        int32 ammo = d.weaponinfo[uint32(s.w_ready.data)].ammo;
        x = [
            int32(s.st_clock),
            s.st_faceindex,
            s.st_facecount,
            s.st_oldhealth,
            s.st_randomnumber,
            int32(g.rndindex),
            s.st_palette,
            int32(s.paletteRevision),
            ammo == 5 ? int32(1994) : g.players[0].ammo[uint32(ammo)],
            s.w_ready.data,
            s.st_fragscount,
            s.keyboxes[0],
            s.keyboxes[1],
            s.keyboxes[2],
            s.st_statusbaron ? int32(1) : int32(0),
            s.st_firsttime ? int32(1) : int32(0),
            s.st_stopped ? int32(1) : int32(0),
            s.st_gamestate,
            s.st_armson ? int32(1) : int32(0),
            s.st_fragson ? int32(1) : int32(0),
            s.st_notdeathmatch ? int32(1) : int32(0),
            s.w_ready.oldnum,
            s.w_health.n.oldnum,
            s.w_armor.n.oldnum
        ];
    }

    function compare(string memory suite) internal {
        ResourceView memory r = source();
        STState memory s;
        STGraphics memory assets;
        VideoState memory v;
        GameState memory g;
        g.mobjs = new Mobj[](2);
        GameDefinitions memory d = definitions();
        V_Video.V_Init(v);
        ST.ST_Init(s, v, assets, r, 0);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
        }
        bytes memory cases =
            vm.readFileBinary(string.concat("test/fixtures/phase4_statusbar/", suite, ".bin"));
        require(cases.length % 336 == 0, "record shape");
        for (uint256 row; row < cases.length / 336; ++row) {
            uint256 base = row * 336;
            int32[36] memory a;
            for (uint256 j; j < 36; ++j) {
                a[j] = be32(cases, base + j * 4);
            }
            input(g, s, a);
            if (row == 0) ST.ST_Start(s, assets, g, d);
            if (a[0] == 0) {
                ST.ST_Ticker(s, g, d);
                ST.ST_Drawer(s, assets, v, g, d, a[25] != 0, a[26] != 0, a[27] != 0);
            } else if (a[0] == 1) {
                ST.ST_Ticker(s, g, d);
            } else if (a[0] == 2) {
                ST.ST_Drawer(s, assets, v, g, d, a[25] != 0, a[26] != 0, a[27] != 0);
            } else if (a[0] == 3) {
                ST.ST_Start(s, assets, g, d);
            } else if (a[0] == 4) {
                ST.ST_Stop(s, assets);
            } else if (a[0] == 6) {
                s.st_faceindex = a[35];
                ST.ST_Drawer(s, assets, v, g, d, a[25] != 0, a[26] != 0, a[27] != 0);
            } else if (a[0] == 5) {
                ST.ST_Responder(s, 1, a[35]);
            }
            int32[24] memory actual = snapshot(s, g, d);
            for (uint256 j; j < 24; ++j) {
                int32 expected = be32(cases, base + 144 + j * 4);
                if (actual[j] != expected) revert StateMismatch(row, j, expected, actual[j]);
            }
            bytes32[3] memory hashes = [
                sha256(v.screens[0]),
                sha256(v.screens[4]),
                sha256(s.paletteRGB.length == 0 ? new bytes(768) : s.paletteRGB)
            ];
            for (uint256 j; j < 3; ++j) {
                bytes32 expected = digest(cases, base + 240 + j * 32);
                if (hashes[j] != expected) revert PixelMismatch(row, j, expected, hashes[j]);
            }
        }
    }

    function testNativeFirstDamageReceiptState() public {
        compare("receipt_damage");
    }

    function testNativeEveryFaceAssetPixels() public {
        compare("all_face_assets");
    }

    function testNativeInventoryAndNumericPixels() public {
        compare("inventory");
    }

    function testNativeNumericEdgesAndSentinels() public {
        compare("numeric_edges");
    }

    function testNativeIdlePainAndRestartTrace() public {
        compare("idle_pain");
    }

    function testNativeSustainedFireAndReleaseTrace() public {
        compare("firing");
    }

    function testNativeFacePrioritiesTrace() public {
        compare("priorities");
    }

    function testNativeAttackerDirectionsAndOriginalOuchBug() public {
        compare("directions");
    }

    function testNativeAllPaletteThresholdsAndGamma() public {
        compare("palettes");
    }

    function testNativeFullscreenAutomapAndRefresh() public {
        compare("visibility");
    }

    function testNativeFacePixelsAcrossPainTiers() public {
        compare("face_pixels");
    }
}
