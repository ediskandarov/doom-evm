// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {DoomScene, StaticCamera} from "../../src/evm/DoomScene.sol";
import {R_Things} from "../../src/doom/r_things.sol";
import {P_SetupStatic} from "../../src/doom/p_setup_static.sol";
import {Info, InfoData} from "../../src/doom/info.sol";
import {SpriteFrame, SpriteDef, VisSprite, RenderThing} from "../../src/doom/r_sprite_state.sol";
import {R_BSP} from "../../src/doom/r_bsp.sol";
import {R_Main} from "../../src/doom/r_main.sol";
import {R_Plane} from "../../src/doom/r_plane.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {R_Segs} from "../../src/doom/r_segs.sol";
import {ColumnView} from "../../src/doom/r_data_types.sol";
import {SpriteBuild} from "../../src/doom/r_sprite_state.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {RenderContext, DrawSeg, Visplane} from "../../src/doom/r_render_state.sol";

interface ThingsVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function readFile(string calldata) external view returns (string memory);
    function parseJsonString(string calldata, string calldata) external pure returns (string memory);
    function parseJsonUint(string calldata, string calldata) external pure returns (uint256);
    function parseJsonBytes32(string calldata, string calldata) external pure returns (bytes32);
    function parseBytes32(string calldata) external pure returns (bytes32);
    function parseJsonInt(string calldata, string calldata) external pure returns (int256);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract RThingsTest {
    ThingsVm constant vm = ThingsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error NativeWordMismatch(string what, uint256 offset, int32 got, int32 expected);
    error NativePixelMismatch(uint256 offset, bytes1 got, bytes1 expected);
    event WallMetrics(
        uint256 angle,
        uint256 initGas,
        uint256 wallGas,
        uint256 allocatorBefore,
        uint256 allocatorAfter,
        uint32 drawsegs,
        uint32 visplanes,
        uint32 openings
    );

    function be32(bytes memory b, uint256 p) private pure returns (uint32 v) {
        for (uint256 j; j < 4; ++j) {
            v = (v << 8) | uint8(b[p + j]);
        }
    }

    function le32(bytes memory b, uint256 p) private pure returns (uint32 v) {
        for (uint256 j; j < 4; ++j) {
            v |= uint32(uint8(b[p + j])) << uint32(j * 8);
        }
    }

    function installChunk(uint256 i) external {
        vm.etch(
            address(uint160(0x100000 + i)),
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"))
        );
    }

    function setUp() public {
        for (uint256 i; i < 1755; ++i) {
            this.installChunk(i);
        }
    }

    function source() private view returns (ResourceView memory v) {
        v.byteLength = 28741889;
        v.chunks = new address[](1755);
        for (uint256 i; i < 1755; ++i) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory d = vm.readFileBinary("test/fixtures/phase2_data/directory.bin");
        v.lumps = new LumpDescriptor[](d.length / 16);
        for (uint256 i; i < v.lumps.length; ++i) {
            uint256 p = i * 16;
            bytes8 name;
            assembly ("memory-safe") { name := mload(add(add(d, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, le32(d, p + 8), le32(d, p + 12));
        }
    }
    event SpriteMetrics(
        uint256 angle, uint256 initializationGas, uint256 projectionGas, uint256 allocator, uint256 count
    );

    function checkWord(bytes memory data, uint256 p, int32 actual) private pure returns (uint256) {
        int32 expected = int32(be32(data, p));
        if (actual != expected) revert NativeWordMismatch("sprite", p, actual, expected);
        return p + 4;
    }

    function init() private view returns (RenderContext memory c, StaticCamera memory camera) {
        (c, camera) = DoomScene.load(source());
        InfoData memory info = Info.load();
        R_Things.R_InitSprites(c, info.spriteNames);
        P_SetupStatic.load(c, info);
    }

    function testOriginalDefinitionsAndStaticThings() public view {
        (RenderContext memory c,) = init();
        bytes memory data = vm.readFileBinary("test/fixtures/phase2_sprites/definitions.bin");
        uint256 p;
        p = checkWord(data, p, int32(uint32(c.sprite.definitions.length)));
        for (uint256 i; i < c.sprite.definitions.length; ++i) {
            p = checkWord(data, p, int32(uint32(c.sprite.definitions[i].frames.length)));
            for (uint256 j; j < c.sprite.definitions[i].frames.length; ++j) {
                SpriteFrame memory f = c.sprite.definitions[i].frames[j];
                p = checkWord(data, p, f.rotate);
                for (uint256 r; r < 8; ++r) {
                    p = checkWord(data, p, f.lump[r]);
                    p = checkWord(data, p, int32(uint32(f.flip[r])));
                }
            }
        }
        require(p == data.length, "definitions length");
        data = vm.readFileBinary("test/fixtures/phase2_sprites/things.bin");
        p = 0;
        p = checkWord(data, p, int32(uint32(c.sprite.things.length)));
        require(c.sprite.things.length == 209);
        for (uint256 i; i < c.sprite.things.length; ++i) {
            RenderThing memory t = c.sprite.things[i];
            p = checkWord(data, p, t.x);
            p = checkWord(data, p, t.y);
            p = checkWord(data, p, t.z);
            p = checkWord(data, p, int32(t.angle));
            p = checkWord(data, p, int32(t.sprite));
            p = checkWord(data, p, int32(t.frame));
            p = checkWord(data, p, int32(t.flags));
            p = checkWord(data, p, int32(t.sector));
            p = checkWord(data, p, int32(t.next));
        }
        p = checkWord(data, p, int32(uint32(c.sprite.sectorHeads.length)));
        for (uint256 i; i < c.sprite.sectorHeads.length; ++i) {
            p = checkWord(data, p, int32(c.sprite.sectorHeads[i]));
        }
        require(p == data.length, "things length");
    }
    function noWall(RenderContext memory, int32, int32) internal pure {}

    function project(uint32 angle) private {
        uint256 gasStart = gasleft();
        (RenderContext memory c, StaticCamera memory camera) = init();
        uint256 initGas = gasStart - gasleft();
        gasStart = gasleft();
        R_Main.R_SetupFrame(c.rs, camera.x, camera.y, camera.z, angle * 0x20000000, 0, -1);
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        R_Things.R_ClearSprites(c);
        R_BSP.R_RenderBSPNode(c, int32(uint32(c.map.nodes.length)) - 1, noWall, R_Things.R_AddSprites);
        R_Things.R_SortVisSprites(c);
        uint256 projectionGas = gasStart - gasleft();
        uint256 allocator;
        assembly ("memory-safe") { allocator := mload(0x40) }
        emit SpriteMetrics(angle, initGas, projectionGas, allocator, c.sprite.visspriteCount);
        bytes memory data = vm.readFileBinary(
            string.concat("test/fixtures/phase2_sprites/angle", vm.toString(angle), "/vissprites.bin")
        );
        uint256 p = checkWord(data, 0, int32(c.sprite.visspriteCount));
        for (uint256 i; i < c.sprite.visspriteCount; ++i) {
            VisSprite memory v = c.sprite.vissprites[i];
            p = checkWord(data, p, v.x1);
            p = checkWord(data, p, v.x2);
            p = checkWord(data, p, v.gx);
            p = checkWord(data, p, v.gy);
            p = checkWord(data, p, v.gz);
            p = checkWord(data, p, v.gzt);
            p = checkWord(data, p, v.startfrac);
            p = checkWord(data, p, v.scale);
            p = checkWord(data, p, v.xiscale);
            p = checkWord(data, p, v.texturemid);
            p = checkWord(data, p, v.patch);
            p = checkWord(data, p, v.colormap);
            p = checkWord(data, p, int32(v.mobjflags));
        }
        require(p == data.length, "projection length");
        data = vm.readFileBinary(
            string.concat("test/fixtures/phase2_sprites/angle", vm.toString(angle), "/sorted.bin")
        );
        p = checkWord(data, 0, int32(c.sprite.visspriteCount));
        for (uint256 i; i < c.sprite.sortedOrder.length; ++i) {
            p = checkWord(data, p, int32(c.sprite.sortedOrder[i]));
        }
        require(p == data.length, "sort length");
    }

    event SpriteStage(string stage, uint256 gasUsed, uint256 allocator);

    function testSpriteStageCosts() public {
        uint256 before = gasleft();
        (RenderContext memory c,) = DoomScene.load(source());
        uint256 allocator;
        assembly ("memory-safe") { allocator := mload(0x40) }
        emit SpriteStage("scene", before - gasleft(), allocator);
        before = gasleft();
        InfoData memory info = Info.load();
        R_Things.R_InitSprites(c, info.spriteNames);
        assembly ("memory-safe") { allocator := mload(0x40) }
        emit SpriteStage("definitions", before - gasleft(), allocator);
        before = gasleft();
        P_SetupStatic.load(c, info);
        assembly ("memory-safe") { allocator := mload(0x40) }
        emit SpriteStage("spawn", before - gasleft(), allocator);
    }

    function syntheticProjectionContext() private pure returns (RenderContext memory c) {
        c.rs.width = 320;
        c.rs.height = 200;
        c.rs.centerxfrac = 160 * 65536;
        c.rs.centeryfrac = 100 * 65536;
        c.rs.projection = 160 * 65536;
        c.rs.viewcos = 65536;
        c.rs.fixedcolormap = -1;
        c.rs.scalelight = new bytes(16 * 48);
        for (uint256 i; i < 48; ++i) {
            c.rs.scalelight[7 * 48 + i] = bytes1(uint8(i % 32));
        }
        c.sprite.light = 7;
        c.resources.spritewidth = new int32[](1);
        c.resources.spritewidth[0] = 8 * 65536;
        c.resources.spriteoffset = new int32[](1);
        c.resources.spritetopoffset = new int32[](1);
        c.resources.spritetopoffset[0] = 8 * 65536;
        c.sprite.definitions = new SpriteDef[](1);
        c.sprite.definitions[0].frames = new SpriteFrame[](1);
        c.sprite.things = new RenderThing[](1);
        R_Things.R_ClearSprites(c);
    }

    function visWords(bytes memory data, uint256 p, VisSprite memory v) private pure returns (uint256) {
        p = checkWord(data, p, v.x1);
        p = checkWord(data, p, v.x2);
        p = checkWord(data, p, v.gx);
        p = checkWord(data, p, v.gy);
        p = checkWord(data, p, v.gz);
        p = checkWord(data, p, v.gzt);
        p = checkWord(data, p, v.startfrac);
        p = checkWord(data, p, v.scale);
        p = checkWord(data, p, v.xiscale);
        p = checkWord(data, p, v.texturemid);
        p = checkWord(data, p, v.patch);
        p = checkWord(data, p, v.colormap);
        return checkWord(data, p, int32(v.mobjflags));
    }

    function testOriginalProjectionEdgesAndOverflow() public view {
        RenderContext memory c = syntheticProjectionContext();
        bytes memory data = vm.readFileBinary("test/fixtures/phase2_sprites/projection-edges.bin");
        uint256 p = checkWord(data, 0, 12);
        for (uint256 i; i < 12; ++i) {
            RenderThing memory t = c.sprite.things[0];
            t.x = 160 * 65536;
            t.y = 0;
            t.z = 0;
            t.frame = 0;
            t.flags = 0;
            c.rs.fixedcolormap = -1;
            c.sprite.definitions[0].frames[0].flip[0] = 0;
            if (i == 1) t.x = 3 * 65536;
            if (i == 2) t.y = -160 * 65536;
            if (i == 3) t.y = 170 * 65536;
            if (i == 4) t.y = 159 * 65536;
            if (i == 5) c.sprite.definitions[0].frames[0].flip[0] = 1;
            if (i == 6) t.flags = 0x40000;
            if (i == 7) {
                t.frame = 0x8000;
                c.rs.fixedcolormap = 3;
            }
            if (i == 8) t.frame = 0x8000;
            if (i == 9) t.flags = 0xc000000;
            if (i == 10) {
                t.flags = 0x40000;
                t.frame = 0x8000;
                c.rs.fixedcolormap = 3;
            }
            if (i == 11) t.x = 4 * 65536;
            R_Things.R_ClearSprites(c);
            R_Things.R_ProjectSprite(c, 0);
            p = checkWord(data, p, int32(c.sprite.visspriteCount));
            if (c.sprite.visspriteCount > 0) p = visWords(data, p, c.sprite.vissprites[0]);
        }
        c.rs.fixedcolormap = -1;
        c.sprite.definitions[0].frames[0].flip[0] = 0;
        R_Things.R_ClearSprites(c);
        for (uint256 i; i < 130; ++i) {
            RenderThing memory t = c.sprite.things[0];
            t.x = 160 * 65536;
            t.y = 0;
            t.z = int32(uint32(i)) * 65536;
            t.frame = 0;
            t.flags = 0;
            R_Things.R_ProjectSprite(c, 0);
        }
        p = checkWord(data, p, int32(c.sprite.visspriteCount));
        p = visWords(data, p, c.sprite.overflowSprite);
        R_Things.R_SortVisSprites(c);
        for (uint256 i; i < 128; ++i) {
            p = checkWord(data, p, int32(c.sprite.sortedOrder[i]));
        }
        require(p == data.length);
    }

    function noMasked(RenderContext memory, uint32, int32, int32) internal pure {
        revert("unexpected mask callback");
    }

    function syntheticPatch() private pure returns (bytes memory patch) {
        patch = new bytes(144);
        patch[0] = 0x08;
        patch[2] = 0x08;
        patch[6] = 0x08;
        for (uint256 x; x < 8; ++x) {
            uint256 offset = 40 + x * 13;
            patch[8 + x * 4] = bytes1(uint8(offset));
            patch[offset + 1] = 0x08;
            for (uint256 y; y < 8; ++y) {
                patch[offset + 3 + y] = bytes1(uint8(0x70 + (x + y) % 16));
            }
            patch[offset + 12] = 0xff;
        }
    }

    function testOriginalDrawModesAndActivePSprites() public {
        (RenderContext memory c,) = init();
        c.sprite.definitions[0].frames = new SpriteFrame[](1);
        c.resources.spritewidth[0] = 8 * 65536;
        c.resources.spriteoffset[0] = 0;
        c.resources.spritetopoffset[0] = 8 * 65536;
        c.resources.lumpcache[c.resources.firstspritelump] = syntheticPatch();
        // The native synthetic projection fixture replaces just this light row.
        for (uint256 i; i < 48; ++i) {
            c.rs.scalelight[7 * 48 + i] = bytes1(uint8(i % 32));
        }
        for (uint256 mode; mode < 14; ++mode) {
            emit SpriteStage("draw mode", mode, 0);
            for (uint256 p; p < 64000; ++p) {
                c.rs.framebuffer[p] = bytes1(uint8(p));
            }
            c.rs.fuzzpos = 0;
            c.rs.fixedcolormap = -1;
            c.sprite.columnMode = 0;
            c.rs.detailshift = mode >= 6 && mode <= 8 ? uint8(1) : uint8(0);
            c.sprite.mfloorclip = c.rs.screenheightarray;
            c.sprite.mceilingclip = c.negonearray;
            VisSprite memory v;
            v.x1 = 140;
            v.x2 = 147;
            v.scale = 65536;
            v.xiscale = 65536;
            v.texturemid = 8 * 65536;
            v.colormap = 7;
            if (mode == 1 || mode == 8) v.colormap = -1;
            if (mode == 2 || mode == 7) v.mobjflags = 1 << 26;
            if (mode >= 9) {
                c.drawsegs = new DrawSeg[](1);
                c.drawsegCount = 1;
                DrawSeg memory d = c.drawsegs[0];
                d.x1 = 140;
                d.x2 = 147;
                d.scale1 = 2 * 65536;
                d.scale2 = 2 * 65536;
                d.silhouette = mode == 9 ? uint8(1) : mode == 10 ? uint8(2) : uint8(3);
                d.bsilheight = 65536;
                d.tsilheight = 7 * 65536;
                d.sprbottomclip = new int32[](320);
                d.sprtopclip = new int32[](320);
                for (uint256 x; x < 320; ++x) {
                    d.sprbottomclip[x] = 96;
                    d.sprtopclip[x] = 93;
                }
                v.gzt = 8 * 65536;
                if (mode == 12) {
                    v.gz = 2 * 65536;
                    v.gzt = 6 * 65536;
                }
                if (mode == 13) {
                    d.scale1 = 32768;
                    d.scale2 = 32768;
                }
                c.sprite.vissprites = new VisSprite[](1);
                c.sprite.vissprites[0] = v;
                R_Things.R_DrawSprite(c, 0, noMasked);
            } else if (mode < 3 || mode >= 6) {
                R_Things.R_DrawVisSprite(c, v, 0, 0);
            } else {
                for (uint256 i; i < 2; ++i) {
                    c.sprite.psprites[i].active = true;
                    c.sprite.psprites[i].sprite = 0;
                    c.sprite.psprites[i].frame = mode == 4 ? uint32(0x8000) : 0;
                    c.sprite.psprites[i].sx = int32(uint32(160 + i * 8)) * 65536;
                    c.sprite.psprites[i].sy = 100 * 65536;
                }
                c.sprite.invisibility = mode == 5 ? int32(129) : int32(0);
                R_Things.R_DrawPlayerSprites(c);
            }
            if (mode == 1 || mode == 5 || mode == 8) {
                require(c.dc.colormap.length == 0, "shadow NULL colormap");
            }
            bytes memory expected = vm.readFileBinary(
                string.concat("test/fixtures/phase2_sprites/draw-edge", vm.toString(mode), ".bin")
            );
            require(keccak256(expected) == keccak256(c.rs.framebuffer), "draw edge");
        }
    }

    function installDefinitionCase(uint256 which) external pure {
        RenderContext memory c;
        c.resources.firstspritelump = 10;
        SpriteBuild memory b;
        b.maxframe = -1;
        for (uint256 f; f < 29; ++f) {
            b.temp[f].rotate = -1;
            for (uint256 r; r < 8; ++r) {
                b.temp[f].lump[r] = -1;
            }
        }
        if (which == 0) {
            R_Things.R_InstallSpriteLump(c, b, 42, 29, 0, false);
        } else if (which == 1) {
            R_Things.R_InstallSpriteLump(c, b, 42, 0, 9, false);
        } else if (which == 2) {
            R_Things.R_InstallSpriteLump(c, b, 42, 0, 0, false);
            R_Things.R_InstallSpriteLump(c, b, 43, 0, 0, false);
        } else if (which == 3) {
            R_Things.R_InstallSpriteLump(c, b, 42, 0, 1, false);
            R_Things.R_InstallSpriteLump(c, b, 43, 0, 0, false);
        } else if (which == 4) {
            R_Things.R_InstallSpriteLump(c, b, 42, 0, 0, false);
            R_Things.R_InstallSpriteLump(c, b, 43, 0, 1, false);
        } else if (which == 5) {
            R_Things.R_InstallSpriteLump(c, b, 42, 0, 1, false);
            R_Things.R_InstallSpriteLump(c, b, 43, 0, 1, false);
        } else {
            R_Things.R_InstallSpriteLump(c, b, 42, 0, 0, true);
            require(b.maxframe == 0 && b.temp[0].rotate == 0);
            for (uint256 i; i < 8; ++i) {
                require(b.temp[0].lump[i] == 32 && b.temp[0].flip[i] == 1);
            }
        }
    }

    function testDefinitionErrorsAndZeroRotation() public {
        for (uint256 i; i < 6; ++i) {
            try this.installDefinitionCase(i) {
                revert("expected definition error");
            } catch (bytes memory why) {
                require(bytes4(why) == R_Things.SpriteDefinition.selector);
            }
        }
        this.installDefinitionCase(6);
        RenderContext memory c;
        c.sprite.definitions = new SpriteDef[](1);
        R_Things.R_InitSpriteDefs(c, hex"");
        require(c.sprite.definitions.length == 0);
    }

    function maskedPost(bytes calldata post) external pure {
        RenderContext memory c;
        c.sprite.mfloorclip = new int32[](1);
        c.sprite.mfloorclip[0] = 200;
        c.sprite.mceilingclip = new int32[](1);
        c.sprite.mceilingclip[0] = -1;
        c.sprite.spryscale = 65536;
        c.dc.texturemid = 123;
        R_Things.R_DrawMaskedColumn(c, ColumnView(post, 0));
        require(c.dc.texturemid == 123);
    }

    function testTerminalAndMalformedPosts() public {
        this.maskedPost(hex"ff");
        this.maskedPost(hex"00000000ff");
        try this.maskedPost(hex"") {
            revert("expected bounds");
        } catch (bytes memory why) {
            require(bytes4(why) == R_Things.SpriteBounds.selector);
        }
        try this.maskedPost(hex"0003ff") {
            revert("expected bounds");
        } catch (bytes memory why) {
            require(bytes4(why) == R_Things.SpriteBounds.selector);
        }
    }

    function testEmptyShadowPreservesNullColormap() public view {
        RenderContext memory c;
        c.resources.source.lumps = new LumpDescriptor[](1);
        c.resources.lumpcache = new bytes[](1);
        c.resources.lumpcache[0] = syntheticPatch();
        c.dc.colormap = new bytes(256);
        VisSprite memory v;
        v.x1 = 320;
        v.x2 = 319;
        v.xiscale = 65536;
        v.scale = 65536;
        v.colormap = -1;
        R_Things.R_DrawVisSprite(c, v, 0, 0);
        require(c.dc.colormap.length == 0 && c.sprite.columnMode == 0 && c.dc.x == 320);
    }

    function testProjectionAngle0() public {
        project(0);
    }

    function testProjectionAngle1() public {
        project(1);
    }

    function testProjectionAngle2() public {
        project(2);
    }

    function testProjectionAngle3() public {
        project(3);
    }

    function testProjectionAngle4() public {
        project(4);
    }

    function testProjectionAngle5() public {
        project(5);
    }

    function testProjectionAngle6() public {
        project(6);
    }

    function testProjectionAngle7() public {
        project(7);
    }
}
