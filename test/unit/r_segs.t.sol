// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_BSP} from "../../src/doom/r_bsp.sol";
import {R_Main} from "../../src/doom/r_main.sol";
import {R_Plane} from "../../src/doom/r_plane.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {R_Segs} from "../../src/doom/r_segs.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {Seg, Side, Line, Sector, Vertex} from "../../src/doom/r_defs.sol";
import {RenderResources, ColumnView, Texture} from "../../src/doom/r_data_types.sol";
import {RenderContext, DrawSeg, Visplane} from "../../src/doom/r_render_state.sol";

interface SegsVm {
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

contract RSegsTest {
    SegsVm constant vm = SegsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
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
    function noSprites(RenderContext memory, uint32) internal pure {}

    function word(bytes memory expected, uint256 p, int32 value, string memory what)
        private
        pure
        returns (uint256)
    {
        int32 native = int32(be32(expected, p));
        if (native != value) revert NativeWordMismatch(what, p, value, native);
        return p + 4;
    }

    function intermediates(RenderContext memory c, string memory dir) private view {
        bytes memory expected = vm.readFileBinary(string.concat(dir, "clips.bin"));
        uint256 p;
        for (uint256 x; x < c.rs.width; ++x) {
            p = word(expected, p, c.floorclip[x], "floorclip");
            p = word(expected, p, c.ceilingclip[x], "ceilingclip");
        }
        require(p == expected.length);
        expected = vm.readFileBinary(string.concat(dir, "planes.bin"));
        p = 0;
        p = word(expected, p, int32(c.visplaneCount), "plane count");
        for (uint256 i; i < c.visplaneCount; ++i) {
            Visplane memory pl = c.visplanes[i];
            p = word(expected, p, pl.height, "plane height");
            p = word(expected, p, int32(pl.picnum), "plane picnum");
            p = word(expected, p, pl.lightlevel, "plane light");
            p = word(expected, p, pl.minx, "plane minx");
            p = word(expected, p, pl.maxx, "plane maxx");
            for (uint256 x; x < 320; ++x) {
                if (pl.top[x + 1] != expected[p]) revert NativePixelMismatch(p, pl.top[x + 1], expected[p]);
                ++p;
            }
            for (uint256 x; x < 320; ++x) {
                if (pl.bottom[x + 1] != expected[p]) {
                    revert NativePixelMismatch(p, pl.bottom[x + 1], expected[p]);
                }
                ++p;
            }
        }
        require(p == expected.length);
        expected = vm.readFileBinary(string.concat(dir, "drawsegs.bin"));
        p = 0;
        p = word(expected, p, int32(c.drawsegCount), "drawseg count");
        for (uint256 i; i < c.drawsegCount; ++i) {
            DrawSeg memory d = c.drawsegs[i];
            p = word(expected, p, int32(d.curline), "seg");
            p = word(expected, p, d.x1, "x1");
            p = word(expected, p, d.x2, "x2");
            p = word(expected, p, d.scale1, "scale1");
            p = word(expected, p, d.scale2, "scale2");
            p = word(expected, p, d.scalestep, "scalestep");
            p = word(expected, p, int32(uint32(d.silhouette)), "silhouette");
            p = word(expected, p, d.bsilheight, "bsilheight");
            p = word(expected, p, d.tsilheight, "tsilheight");
            for (uint256 a; a < 3; ++a) {
                int32[] memory values = a == 0 ? d.sprtopclip : a == 1 ? d.sprbottomclip : d.maskedtexturecol;
                p = word(expected, p, values.length == 0 ? int32(0) : int32(1), "clip pointer");
                if (values.length != 0) {
                    for (int32 x = d.x1; x <= d.x2; ++x) {
                        p = word(expected, p, values[uint32(x)], "drawseg array");
                    }
                }
            }
        }
        require(p == expected.length);
    }

    function render(uint32 angle) private returns (RenderContext memory c) {
        uint256 start = gasleft();
        c.resources = R_Data.R_InitDataLazy(source());
        c.map = R_Data.R_LoadMap(c.resources, "E1M1");
        c.skyflatnum = R_Data.R_FlatNumForName(c.resources, "F_SKY1");
        c.skytexture = R_Data.R_TextureNumForName(c.resources, "SKY1");
        c.skytexturemid = 100 * 65536;
        R_Main.R_ExecuteSetViewSize(c.rs, 11, 0);
        c.rs.validcount = 1;
        R_Main.R_SetupFrame(c.rs, -27262976, 16777216, 2686976, angle, 0, -1);
        c.rs.framebuffer = new bytes(64000);
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        uint256 initGas = start - gasleft();
        uint256 beforeMem;
        assembly ("memory-safe") { beforeMem := mload(0x40) }
        start = gasleft();
        R_BSP.R_RenderBSPNode(c, int32(uint32(c.map.nodes.length - 1)), R_Segs.R_StoreWallRange, noSprites);
        uint256 wallGas = start - gasleft();
        uint256 afterMem;
        assembly ("memory-safe") { afterMem := mload(0x40) }
        emit WallMetrics(
            angle, initGas, wallGas, beforeMem, afterMem, c.drawsegCount, c.visplaneCount, c.openingCount
        );
    }

    function check(uint256 angle) private {
        string memory name = string.concat("walls-angle", vm.toString(angle));
        string memory dir = string.concat("test/fixtures/renderer/", name, "/");
        string memory manifest = vm.readFile("test/fixtures/renderer/manifest.json");
        string memory key = string.concat(".cases[", vm.toString(angle * 2), "]");
        // Manifest ordering is discovered by name, never presumed from generic v0 metadata.
        for (uint256 i; i < 16; ++i) {
            string memory candidate = string.concat(".cases[", vm.toString(i), "]");
            if (
                keccak256(bytes(vm.parseJsonString(manifest, string.concat(candidate, ".name"))))
                    == keccak256(bytes(name))
            ) {
                key = candidate;
                break;
            }
        }
        require(
            keccak256(bytes(vm.parseJsonString(manifest, string.concat(key, ".name"))))
                == keccak256(bytes(name)),
            "native case name"
        );
        require(
            keccak256(bytes(vm.parseJsonString(manifest, string.concat(key, ".mode")))) == keccak256("walls"),
            "native render pass"
        );
        require(
            vm.parseJsonUint(manifest, string.concat(key, ".angle")) == angle * 0x20000000, "native angle"
        );
        bytes memory expected = vm.readFileBinary(string.concat(dir, "pixels.bin"));
        string memory refdoc = vm.readFile(string.concat(dir, "reference.json"));
        require(
            sha256(expected)
                == vm.parseBytes32(string.concat("0x", vm.parseJsonString(refdoc, ".frameSha256"))),
            "reference frame identity"
        );
        require(
            sha256(expected)
                == vm.parseBytes32(
                    string.concat("0x", vm.parseJsonString(manifest, string.concat(key, ".frameSha256")))
                ),
            "manifest frame identity"
        );
        require(
            vm.parseJsonUint(refdoc, ".schemaVersion") == 0 && vm.parseJsonUint(refdoc, ".width") == 320
                && vm.parseJsonUint(refdoc, ".height") == 200,
            "native frame format"
        );
        require(
            vm.parseJsonInt(refdoc, ".camera.x") == -27262976
                && vm.parseJsonInt(refdoc, ".camera.y") == 16777216
                && vm.parseJsonInt(refdoc, ".camera.z") == 2686976
                && vm.parseJsonUint(refdoc, ".camera.angle") == angle * 0x20000000,
            "native camera"
        );
        require(
            vm.parseJsonInt(refdoc, ".lighting.extraLight") == 0
                && vm.parseJsonInt(refdoc, ".lighting.fixedColormap") == -1
                && vm.parseJsonUint(refdoc, ".gametic") == 0,
            "native settings"
        );
        require(keccak256(bytes(vm.parseJsonString(refdoc, ".detail"))) == keccak256("high"), "native detail");
        require(
            keccak256(bytes(vm.parseJsonString(refdoc, ".provenance.map"))) == keccak256("E1M1"), "native map"
        );
        require(
            keccak256(bytes(vm.parseJsonString(refdoc, ".provenance.upstreamCommit")))
                == keccak256("a77dfb96cb91780ca334d0d4cfd86957558007e0"),
            "native source"
        );
        require(
            vm.parseBytes32(string.concat("0x", vm.parseJsonString(refdoc, ".resourceIdentity.wadSha256")))
                == 0x7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d,
            "native WAD"
        );
        require(
            vm.parseBytes32(string.concat("0x", vm.parseJsonString(refdoc, ".resourceIdentity.bundleSha256")))
                == 0xd379076f21645cf7cc5acb056663d0faacc4065489a0ca99738479323c9f7a47,
            "native bundle"
        );
        require(
            vm.parseBytes32(
                    string.concat("0x", vm.parseJsonString(refdoc, ".resourceIdentity.paletteSha256"))
                ) == 0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb,
            "native palette"
        );
        RenderContext memory c = render(uint32(angle * 0x20000000));
        require(expected.length == 64000 && c.rs.framebuffer.length == 64000);
        for (uint256 i; i < 64000; ++i) {
            if (c.rs.framebuffer[i] != expected[i]) {
                revert NativePixelMismatch(i, c.rs.framebuffer[i], expected[i]);
            }
        }
        intermediates(c, dir);
    }

    function testOriginalWallAngle0() public {
        check(0);
    }

    function testOriginalWallAngle1() public {
        check(1);
    }

    function testOriginalWallAngle2() public {
        check(2);
    }

    function testOriginalWallAngle3() public {
        check(3);
    }

    function testOriginalWallAngle4() public {
        check(4);
    }

    function testOriginalWallAngle5() public {
        check(5);
    }

    function testOriginalWallAngle6() public {
        check(6);
    }

    function testOriginalWallAngle7() public {
        check(7);
    }

    function syntheticContext(RenderResources memory resources, int32[23] memory a)
        private
        pure
        returns (RenderContext memory c)
    {
        c.resources = resources;
        c.map.vertexes = new Vertex[](2);
        c.map.vertexes[0] = Vertex(128 * 65536, 128 * 65536);
        c.map.vertexes[1] = Vertex(128 * 65536, -128 * 65536);
        if (a[21] == 1) {
            c.map.vertexes[0] = Vertex(-128 * 65536, 128 * 65536);
            c.map.vertexes[1] = Vertex(128 * 65536, 128 * 65536);
        }
        if (a[21] == 2) {
            c.map.vertexes[0].x = 192 * 65536;
            c.map.vertexes[1].x = 64 * 65536;
        }
        c.skyflatnum = R_Data.R_FlatNumForName(resources, "F_SKY1");
        c.map.sectors = new Sector[](2);
        c.map.sectors[0] = Sector(a[0] * 65536, a[1] * 65536, 1, a[12] != 0 ? c.skyflatnum : 2, int16(a[14]));
        c.map.sectors[1] = Sector(a[2] * 65536, a[3] * 65536, 1, a[13] != 0 ? c.skyflatnum : 2, int16(a[15]));
        c.map.sides = new Side[](1);
        c.map.sides[0] = Side(a[10] * 65536, a[9] * 65536, uint32(a[7]), uint32(a[8]), uint32(a[6]), 0);
        c.map.lines = new Line[](1);
        c.map.lines[0].flags = uint16(uint32(a[5]));
        c.map.lines[0].v2 = 1;
        c.map.segs = new Seg[](1);
        c.map.segs[0].v2 = 1;
        c.map.segs[0].offset = a[11] * 65536;
        c.map.segs[0].angle = R_Main.R_PointToAngle2(
            c.rs, c.map.vertexes[0].x, c.map.vertexes[0].y, c.map.vertexes[1].x, c.map.vertexes[1].y
        );
        c.map.segs[0].backsector = a[4] != 0 ? 1 : type(uint32).max;
        c.resources.texturetranslation[1] = a[20] != 0 ? 2 : 1;
        R_Main.R_ExecuteSetViewSize(c.rs, 11, 0);
        R_Main.R_SetupFrame(c.rs, 0, 0, 41 * 65536, a[21] == 1 ? uint32(0x40000000) : 0, a[19], a[18]);
        c.rs.framebuffer = new bytes(64000);
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        c.backsector = c.map.segs[0].backsector;
        if (c.map.sectors[0].floorheight < c.rs.viewz) {
            c.floorplane =
                R_Plane.R_FindPlane(c, c.map.sectors[0].floorheight, 1, c.map.sectors[0].lightlevel);
        }
        if (c.map.sectors[0].ceilingheight > c.rs.viewz || a[12] != 0) {
            c.ceilingplane = R_Plane.R_FindPlane(
                c, c.map.sectors[0].ceilingheight, c.map.sectors[0].ceilingpic, c.map.sectors[0].lightlevel
            );
        }
        c.wall.rw_angle1 = R_Main.R_PointToAngle(c.rs, c.map.vertexes[0].x, c.map.vertexes[0].y);
        if (a[22] != 0) {
            c.wall.rw_scalestep = 12345;
            c.drawsegs[0].scalestep = 54321;
        }
    }

    function syntheticGlobals(RenderContext memory c, bytes memory expected) private pure {
        int32[33] memory values = [
            c.wall.segtextured ? int32(1) : int32(0),
            c.wall.markfloor ? int32(1) : int32(0),
            c.wall.markceiling ? int32(1) : int32(0),
            c.wall.maskedtexture ? int32(1) : int32(0),
            int32(c.wall.toptexture),
            int32(c.wall.bottomtexture),
            int32(c.wall.midtexture),
            int32(c.wall.rw_normalangle),
            int32(c.wall.rw_angle1),
            c.wall.rw_x,
            c.wall.rw_stopx,
            int32(c.wall.rw_centerangle),
            c.wall.rw_offset,
            c.wall.rw_distance,
            c.wall.rw_scale,
            c.wall.rw_scalestep,
            c.wall.rw_midtexturemid,
            c.wall.rw_toptexturemid,
            c.wall.rw_bottomtexturemid,
            c.wall.worldtop,
            c.wall.worldbottom,
            c.wall.worldhigh,
            c.wall.worldlow,
            c.wall.pixhigh,
            c.wall.pixlow,
            c.wall.pixhighstep,
            c.wall.pixlowstep,
            c.wall.topfrac,
            c.wall.topstep,
            c.wall.bottomfrac,
            c.wall.bottomstep,
            int32(uint32(c.map.lines[0].flags)),
            int32(c.openingCount)
        ];
        uint256 p;
        for (uint256 i; i < 33; ++i) {
            if (i == 0) {
                require((int32(be32(expected, p)) != 0) == c.wall.segtextured, "native segtextured truth");
                p += 4;
            } else {
                p = word(expected, p, values[i], "wall global");
            }
        }
        require(p == expected.length);
    }

    function syntheticRange(uint256 begin, uint256 end) private view {
        RenderResources memory resources = R_Data.R_InitDataLazy(source());
        bytes memory cases = vm.readFileBinary("test/fixtures/phase2_segs/cases.bin");
        require(cases.length == 25 * 23 * 4);
        for (uint256 k = begin; k < end; ++k) {
            int32[23] memory a;
            for (uint256 j; j < 23; ++j) {
                a[j] = int32(be32(cases, k * 92 + j * 4));
            }
            RenderContext memory c = syntheticContext(resources, a);
            R_Segs.R_StoreWallRange(c, a[16], a[17]);
            string memory dir = string.concat("test/fixtures/phase2_segs/", vm.toString(k), "/");
            bytes memory expected = vm.readFileBinary(string.concat(dir, "pixels.bin"));
            require(expected.length == 64000);
            for (uint256 i; i < 64000; ++i) {
                if (c.rs.framebuffer[i] != expected[i]) {
                    revert NativePixelMismatch(i, c.rs.framebuffer[i], expected[i]);
                }
            }
            intermediates(c, dir);
            syntheticGlobals(c, vm.readFileBinary(string.concat(dir, "globals.bin")));
        }
    }

    function testNativeSyntheticOneSided() public view {
        syntheticRange(0, 1);
    }

    function testNativeSyntheticBottomPegged() public view {
        syntheticRange(1, 2);
    }

    function testNativeSyntheticNegativeRowoffset() public view {
        syntheticRange(2, 3);
    }

    function testNativeSyntheticTranslatedHeightOriginal() public view {
        syntheticRange(3, 4);
    }

    function testNativeSyntheticWindowPegging0() public view {
        syntheticRange(4, 5);
    }

    function testNativeSyntheticWindowPegging8() public view {
        syntheticRange(5, 6);
    }

    function testNativeSyntheticWindowPegging16() public view {
        syntheticRange(6, 7);
    }

    function testNativeSyntheticWindowPegging24() public view {
        syntheticRange(7, 8);
    }

    function testNativeSyntheticMaskedWindow() public view {
        syntheticRange(8, 9);
    }

    function testNativeSyntheticMaskedIdentical() public view {
        syntheticRange(9, 10);
    }

    function testNativeSyntheticBothSilhouettes() public view {
        syntheticRange(10, 11);
    }

    function testNativeSyntheticFloorAboveEye() public view {
        syntheticRange(11, 12);
    }

    function testNativeSyntheticCeilingBelowEye() public view {
        syntheticRange(12, 13);
    }

    function testNativeSyntheticClosedBottom() public view {
        syntheticRange(13, 14);
    }

    function testNativeSyntheticClosedTop() public view {
        syntheticRange(14, 15);
    }

    function testNativeSyntheticJoinedSky() public view {
        syntheticRange(15, 16);
    }

    function testNativeSyntheticFrontOnlySky() public view {
        syntheticRange(16, 17);
    }

    function testNativeSyntheticFrontFloorAboveEye() public view {
        syntheticRange(17, 18);
    }

    function testNativeSyntheticFrontCeilingBelowEye() public view {
        syntheticRange(18, 19);
    }

    function testNativeSyntheticFixedColormap() public view {
        syntheticRange(19, 20);
    }

    function testNativeSyntheticBrightClamp() public view {
        syntheticRange(20, 21);
    }

    function testNativeSyntheticDarkClamp() public view {
        syntheticRange(21, 22);
    }

    function testNativeSyntheticSingleColumnStaleStep() public view {
        syntheticRange(22, 23);
    }

    function testNativeSyntheticHorizontalLight() public view {
        syntheticRange(23, 24);
    }

    function testNativeSyntheticDiagonalLight() public view {
        syntheticRange(24, 25);
    }

    function malformed(uint8 kind) external view {
        RenderContext memory c;
        c.rs.width = 320;
        c.drawsegs = new DrawSeg[](256);
        if (kind < 3) {
            R_Segs.R_StoreWallRange(c, kind == 0 ? int32(-1) : int32(1), kind == 1 ? int32(0) : int32(320));
            return;
        }
        c.map.segs = new Seg[](1);
        c.map.vertexes = new Vertex[](1);
        c.map.sides = new Side[](1);
        c.map.lines = new Line[](1);
        c.map.sectors = new Sector[](1);
        c.wall.rw_angle1 = 0xc0000000; // normal90-angle270 -> wrapped signed INT_MIN.
        R_Segs.R_StoreWallRange(c, 1, 1);
    }

    function testExplicitWallBoundsAndUndefinedAbs() public {
        for (uint8 kind; kind < 4; ++kind) {
            (bool ok, bytes memory reason) = address(this).call(abi.encodeCall(this.malformed, (kind)));
            require(!ok);
            require(
                bytes4(reason) == (kind < 3 ? R_Segs.WallBounds.selector : R_Segs.UndefinedWallAngle.selector)
            );
        }
        RenderContext memory c;
        c.drawsegCount = 256;
        R_Segs.R_StoreWallRange(c, -1, -1);
        require(c.drawsegCount == 256, "original exhaustion no-op");
    }

    function openingBoundary(bool overflow) external view {
        RenderResources memory resources = R_Data.R_InitDataLazy(source());
        bytes memory cases = vm.readFileBinary("test/fixtures/phase2_segs/cases.bin");
        int32[23] memory a;
        for (uint256 j; j < 23; ++j) {
            a[j] = int32(be32(cases, 8 * 92 + j * 4));
        }
        RenderContext memory c = syntheticContext(resources, a);
        c.openingCount = overflow ? uint32(20480) : uint32(20000);
        R_Segs.R_StoreWallRange(c, a[16], a[17]);
        require(c.openingCount == 20480, "original short allocation accounting");
    }

    function testOpeningCapacityExactBoundaryAndOverflow() public {
        this.openingBoundary(false);
        (bool ok, bytes memory reason) = address(this).call(abi.encodeCall(this.openingBoundary, (true)));
        require(!ok && bytes4(reason) == R_Segs.OpeningOverflow.selector, "missing explicit opening cap");
    }

    function observeMasked(RenderContext memory c, ColumnView memory post) internal pure {
        bytes memory expected = c.ds.source;
        uint256 p = c.rs.fuzzpos;
        p = word(expected, p, c.dc.x, "masked x");
        p = word(expected, p, c.dc.texturemid, "masked texturemid");
        p = word(expected, p, c.dc.iscale, "masked iscale");
        p = word(expected, p, c.sprite.spryscale, "masked spryscale");
        p = word(expected, p, c.sprite.sprtopscreen, "masked topscreen");
        p = word(expected, p, c.sprite.mfloorclip[uint32(c.dc.x)], "masked floorclip");
        p = word(expected, p, c.sprite.mceilingclip[uint32(c.dc.x)], "masked ceilingclip");
        uint32 count = be32(expected, p);
        p += 4;
        for (uint256 i; i < 256; ++i) {
            if (c.dc.colormap[i] != expected[p]) {
                revert NativePixelMismatch(p, c.dc.colormap[i], expected[p]);
            }
            ++p;
        }
        uint256 end = post.offset;
        while (post.data[end] != 0xff) end += uint8(post.data[end + 1]) + 4;
        ++end;
        require(end - post.offset == count, "native post stream length");
        for (uint256 i = post.offset; i < end; ++i) {
            if (post.data[i] != expected[p]) revert NativePixelMismatch(p, post.data[i], expected[p]);
            ++p;
        }
        c.rs.fuzzpos = uint32(p);
        if (c.rs.framecount == 4) c.dc.x *= 2;
    }

    function maskedCase(uint256 k) private view {
        RenderResources memory resources = R_Data.R_InitDataLazy(source());
        bytes memory cases = vm.readFileBinary("test/fixtures/phase2_segs/masked-cases.bin");
        require(cases.length == 6 * 96);
        int32[23] memory a;
        for (uint256 j; j < 23; ++j) {
            a[j] = int32(be32(cases, k * 96 + j * 4));
        }
        uint32 mode = be32(cases, k * 96 + 92);
        RenderContext memory c = syntheticContext(resources, a);
        R_Segs.R_StoreWallRange(c, a[16], a[17]);
        string memory dir = string.concat("test/fixtures/phase2_segs/masked-", vm.toString(k), "/");
        c.ds.source = vm.readFileBinary(string.concat(dir, "masked-trace.bin"));
        c.rs.fuzzpos = 0;
        c.rs.framecount = mode;
        if (mode == 3) {
            for (int32 x = a[16]; x <= a[17]; x += 2) {
                c.drawsegs[0].maskedtexturecol[uint32(x)] = 32767;
            }
        }
        if (mode == 2) {
            R_Segs.R_RenderMaskedSegRange(c, 0, a[16] + 10, a[17] - 10, observeMasked);
            R_Segs.R_RenderMaskedSegRange(c, 0, a[16], a[17], observeMasked);
            R_Segs.R_RenderMaskedSegRange(c, 0, a[17] + 1, a[17], observeMasked);
        } else {
            R_Segs.R_RenderMaskedSegRange(c, 0, a[16], a[17], observeMasked);
            if (mode == 1) R_Segs.R_RenderMaskedSegRange(c, 0, a[16], a[17], observeMasked);
        }
        require(c.rs.fuzzpos == c.ds.source.length, "native masked callback count");
        intermediates(c, dir);
        syntheticGlobals(c, vm.readFileBinary(string.concat(dir, "globals.bin")));
        bytes memory state = vm.readFileBinary(string.concat(dir, "masked-state.bin"));
        uint256 p;
        p = word(state, p, c.dc.x, "masked final x");
        p = word(state, p, c.dc.texturemid, "masked final texturemid");
        p = word(state, p, c.dc.iscale, "masked final iscale");
        p = word(state, p, c.sprite.spryscale, "masked final scale");
        p = word(state, p, c.sprite.sprtopscreen, "masked final screen");
        p = word(state, p, c.wall.rw_scalestep, "masked final step");
        p = word(state, p, c.wall.lightnum, "masked light row");
        for (uint256 i; i < 256; ++i) {
            require(c.dc.colormap[i] == state[p++], "masked final colormap");
        }
        require(p == state.length);
        int32[] memory floor = c.sprite.mfloorclip;
        int32[] memory bottom = c.drawsegs[0].sprbottomclip;
        int32[] memory ceiling = c.sprite.mceilingclip;
        int32[] memory top = c.drawsegs[0].sprtopclip;
        bool aliases;
        assembly ("memory-safe") { aliases := and(eq(floor, bottom), eq(ceiling, top)) }
        require(aliases, "masked clip pointer aliases");
    }

    function testNativeMaskedRepeatedRange() public view {
        maskedCase(0);
    }

    function testNativeMaskedPartialFinalAndEmptyRanges() public view {
        maskedCase(1);
    }

    function testNativeMaskedSentinelsFixedLightBottomPeg() public view {
        maskedCase(2);
    }

    function testNativeMaskedCallbackXMutation() public view {
        maskedCase(3);
    }

    function testNativeMaskedTranslatedPeggingHeight() public view {
        maskedCase(4);
    }

    function testNativeMaskedDiagonalLight() public view {
        maskedCase(5);
    }

    function terminalContext() private pure returns (RenderContext memory c) {
        c.rs.width = 1;
        c.rs.height = 200;
        c.rs.scalelight = new bytes(16 * 48);
        c.rs.fixedcolormap = -1;
        c.resources.colormaps = new bytes(256);
        c.resources.textures = new Texture[](1);
        c.resources.texturetranslation = new uint32[](1);
        c.resources.textures[0].height = 128;
        c.resources.textures[0].width = 1;
        c.resources.textures[0].columnlump = new int32[](1);
        c.resources.textures[0].columnlump[0] = 1;
        c.resources.textures[0].columnofs = new uint32[](1);
        c.resources.textures[0].columnofs[0] = 3;
        c.resources.lumpcache = new bytes[](2);
        c.resources.lumpcache[1] = hex"ff";
        c.map.vertexes = new Vertex[](1);
        c.map.segs = new Seg[](1);
        c.map.segs[0].backsector = 1;
        c.map.sides = new Side[](1);
        c.map.lines = new Line[](1);
        c.map.sectors = new Sector[](2);
        c.map.sectors[0].ceilingheight = 128 * 65536;
        c.map.sectors[1].ceilingheight = 128 * 65536;
        c.drawsegs = new DrawSeg[](1);
        c.drawsegCount = 1;
        c.drawsegs[0].scale1 = 65536;
        c.drawsegs[0].maskedtexturecol = new int32[](1);
        c.drawsegs[0].sprtopclip = new int32[](1);
        c.drawsegs[0].sprtopclip[0] = -1;
        c.drawsegs[0].sprbottomclip = new int32[](1);
        c.drawsegs[0].sprbottomclip[0] = 200;
    }

    function terminal(RenderContext memory c, ColumnView memory post) internal pure {
        require(
            post.offset == 0 && post.data.length == 1 && post.data[0] == 0xff, "empty virtual pixel pointer"
        );
        ++c.rs.fuzzpos;
    }

    function testMaskedVirtualTerminalAndConsumedSentinel() public view {
        RenderContext memory c = terminalContext();
        R_Segs.R_RenderMaskedSegRange(c, 0, 0, 0, terminal);
        R_Segs.R_RenderMaskedSegRange(c, 0, 0, 0, terminal);
        require(c.rs.fuzzpos == 1 && c.drawsegs[0].maskedtexturecol[0] == 32767);
    }

    function malformedMasked(uint8 op) external view {
        RenderContext memory c = terminalContext();
        if (op == 0) {
            R_Segs.R_RenderMaskedSegRange(c, 1, 0, 0, terminal);
            return;
        }
        if (op == 1) {
            R_Segs.R_RenderMaskedSegRange(c, 0, -1, 0, terminal);
            return;
        }
        if (op == 2) {
            R_Segs.R_RenderMaskedSegRange(c, 0, 0, 1, terminal);
            return;
        }
        if (op == 3) c.map.segs[0].backsector = type(uint32).max;
        if (op == 4) c.drawsegs[0].scale1 = 0;
        R_Segs.R_RenderMaskedSegRange(c, 0, 0, 0, terminal);
    }

    function testMaskedRangeBoundsAndZeroScale() public {
        for (uint8 i; i < 5; ++i) {
            (bool ok, bytes memory reason) = address(this).call(abi.encodeCall(this.malformedMasked, (i)));
            require(!ok && bytes4(reason) == R_Segs.WallBounds.selector, "masked undefined domain accepted");
        }
    }
}
