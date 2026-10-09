// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {DoomScene, StaticCamera} from "../../src/evm/DoomScene.sol";
import {R_BSP} from "../../src/doom/r_bsp.sol";
import {R_Main} from "../../src/doom/r_main.sol";
import {R_Plane} from "../../src/doom/r_plane.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {R_Segs} from "../../src/doom/r_segs.sol";
import {Texture} from "../../src/doom/r_data_types.sol";
import {R_Draw} from "../../src/doom/r_draw.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {RenderContext, DrawSeg, Visplane} from "../../src/doom/r_render_state.sol";

interface PlanesVm {
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

contract RPlanesTest {
    PlanesVm constant vm = PlanesVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    error NativeWordMismatch(string what, uint256 offset, int32 got, int32 expected);
    error NativePixelMismatch(uint256 offset, bytes1 got, bytes1 expected);
    event PlaneMetrics(
        uint256 angle,
        uint256 initGas,
        uint256 wallGas,
        uint256 planeGas,
        uint256 allocatorAtPlanes,
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

    function render(uint32 angle) private returns (RenderContext memory c) {
        uint256 start = gasleft();
        StaticCamera memory camera;
        (c, camera) = DoomScene.load(source());
        R_Main.R_SetupFrame(c.rs, camera.x, camera.y, camera.z, angle, 0, -1);
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        uint256 initGas = start - gasleft();
        uint256 beforeMem;
        assembly ("memory-safe") { beforeMem := mload(0x40) }
        start = gasleft();
        R_BSP.R_RenderBSPNode(c, int32(uint32(c.map.nodes.length - 1)), R_Segs.R_StoreWallRange, noSprites);
        uint256 wallGas = start - gasleft();
        uint256 atPlanes;
        assembly ("memory-safe") { atPlanes := mload(0x40) }
        start = gasleft();
        R_Plane.R_DrawPlanes(c);
        uint256 planeGas = start - gasleft();
        uint256 afterMem;
        assembly ("memory-safe") { afterMem := mload(0x40) }
        emit PlaneMetrics(
            angle,
            initGas,
            wallGas,
            planeGas,
            atPlanes,
            beforeMem,
            afterMem,
            c.drawsegCount,
            c.visplaneCount,
            c.openingCount
        );
    }

    function check(uint256 angle) private {
        string memory name = string.concat("full-angle", vm.toString(angle));
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
            keccak256(bytes(vm.parseJsonString(manifest, string.concat(key, ".mode")))) == keccak256("full"),
            "native render pass"
        );
        require(
            vm.parseJsonUint(manifest, string.concat(key, ".angle")) == angle * 0x20000000, "native angle"
        );
        bytes memory expected = vm.readFileBinary(string.concat(dir, "plane-pixels.bin"));
        string memory refdoc = vm.readFile(string.concat(dir, "reference.json"));
        require(
            sha256(expected)
                == vm.parseBytes32(
                    string.concat(
                        "0x",
                        vm.parseJsonString(manifest, string.concat('.files["', name, '/plane-pixels.bin"]'))
                    )
                ),
            "manifest plane snapshot identity"
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
    }

    function testOriginalPlaneAngle0() public {
        check(0);
    }

    function testOriginalPlaneAngle1() public {
        check(1);
    }

    function testOriginalPlaneAngle2() public {
        check(2);
    }

    function testOriginalPlaneAngle3() public {
        check(3);
    }

    function testOriginalPlaneAngle4() public {
        check(4);
    }

    function testOriginalPlaneAngle5() public {
        check(5);
    }

    function testOriginalPlaneAngle6() public {
        check(6);
    }

    function testOriginalPlaneAngle7() public {
        check(7);
    }

    function synthetic(int32[10] memory a) private pure returns (RenderContext memory c) {
        c.rs.width = 8;
        c.rs.height = 8;
        c.rs.centery = 4;
        c.rs.centerxfrac = 4 * 65536;
        c.rs.viewx = 12345;
        c.rs.viewy = -54321;
        c.rs.viewz = 65536;
        c.rs.viewangle = uint32(a[6]);
        c.rs.detailshift = uint8(uint32(a[7]));
        c.rs.pspriteiscale = 65536;
        c.rs.fixedcolormap = a[5];
        c.rs.framebuffer = new bytes(64000);
        c.rs.ylookup = new uint32[](200);
        c.rs.columnofs = new uint32[](320);
        c.rs.yslope = new int32[](200);
        c.rs.distscale = new int32[](320);
        c.rs.xtoviewangle = new uint32[](321);
        for (uint32 y; y < 200; ++y) {
            c.rs.yslope[y] = int32((y + 1) * 16384);
            c.rs.ylookup[y] = y * 320;
        }
        for (uint32 x; x < 320; ++x) {
            c.rs.distscale[x] = int32(65536 + x * 8192);
            c.rs.columnofs[x] = x;
            unchecked {
                c.rs.xtoviewangle[x] = x * 0x1000000;
            }
        }
        c.resources.colormaps = new bytes(34 * 256);
        for (uint256 i; i < 34 * 256; ++i) {
            c.resources.colormaps[i] = bytes1(uint8(i % 256 + (i / 256) * 7));
        }
        c.rs.zlight = new bytes(16 * 128);
        for (uint256 i; i < 16; ++i) {
            for (uint256 j; j < 128; ++j) {
                c.rs.zlight[i * 128 + j] = bytes1(uint8((i + j) % 32));
            }
        }
        c.resources.lumpcache = new bytes[](4);
        c.resources.lumpcache[1] = new bytes(128 * 128);
        c.resources.lumpcache[2] = new bytes(4096);
        c.resources.lumpcache[3] = new bytes(4096);
        for (uint256 i; i < 4096; ++i) {
            c.resources.lumpcache[2][i] = bytes1(uint8(i * 13));
            c.resources.lumpcache[3][i] = bytes1(uint8(i * 17 + 23));
        }
        for (uint256 x; x < 128; ++x) {
            for (uint256 y; y < 128; ++y) {
                c.resources.lumpcache[1][x * 128 + y] = bytes1(uint8(x * 3 + y * 5));
            }
        }
        c.resources.textures = new Texture[](2);
        Texture memory tex = c.resources.textures[0];
        tex.widthmask = 127;
        tex.columnlump = new int32[](128);
        tex.columnofs = new uint32[](128);
        for (uint32 i; i < 128; ++i) {
            tex.columnlump[i] = 1;
            tex.columnofs[i] = i * 128;
        }
        c.resources.texturetranslation = new uint32[](2);
        c.resources.texturetranslation[0] = 1;
        c.resources.numflats = 2;
        c.resources.firstflat = 2;
        c.resources.flattranslation = new uint32[](2);
        c.resources.flattranslation[0] = 1;
        c.skyflatnum = 99;
        c.skytexturemid = 100 * 65536;
        R_Plane.R_ClearPlanes(c);
        c.ds.source = c.resources.lumpcache[2];
        c.plane.light = 3;
    }

    function runVector(int32[10] memory a) external view returns (bytes32) {
        RenderContext memory c = synthetic(a);
        if (a[0] == 0) {
            c.plane.planeheight = a[1];
            if (a[8] != 0) {
                uint32 y = uint32(a[2]);
                c.plane.cachedheight[y] = a[1];
                c.plane.cacheddistance[y] = a[8];
                c.plane.cachedxstep[y] = 123;
                c.plane.cachedystep[y] = -456;
                if (a[9] != 0) R_Plane.R_ClearPlanes(c);
            }
            R_Plane.R_MapPlane(c, a[2], a[3], a[4]);
        } else if (a[0] == 1) {
            c.plane.planeheight = 2 * 65536;
            for (uint256 y; y < 200; ++y) {
                c.plane.spanstart[y] = 1;
            }
            R_Plane.R_MakeSpans(c, a[1], a[2], a[3], a[4], a[8]);
        } else if (a[0] == 2) {
            uint32 n = R_Plane.R_FindPlane(c, a[1], a[2] != 0 ? c.skyflatnum : 0, int16(a[3]));
            n = R_Plane.R_CheckPlane(c, n, 0, 7);
            Visplane memory pl = c.visplanes[n];
            for (uint256 x; x < 8; ++x) {
                pl.top[x + 1] = bytes1(uint8(1 + x % 3));
                pl.bottom[x + 1] = bytes1(uint8(5 + x % 2));
            }
            c.rs.extralight = a[4];
            R_Plane.R_DrawPlanes(c);
        } else {
            uint32 n = R_Plane.R_FindPlane(c, 123, 0, 77);
            n = R_Plane.R_CheckPlane(c, n, 1, 5);
            Visplane memory pl = c.visplanes[n];
            pl.top[4] = 0x02;
            R_Plane.R_CheckPlane(c, n, 2, 4);
            R_Plane.R_FindPlane(c, 99, c.skyflatnum, 100);
            R_Plane.R_FindPlane(c, -999, c.skyflatnum, -10);
            pl.top[0] = 0x11;
            pl.top[321] = 0x12;
            pl.bottom[8] = 0x5b;
            c.plane.cachedheight[2] = 9;
            c.plane.cacheddistance[2] = 34;
            c.plane.cachedxstep[2] = 56;
            c.plane.cachedystep[2] = 78;
            c.plane.spanstart[2] = 4;
            R_Plane.R_ClearPlanes(c);
            R_Plane.R_FindPlane(c, 456, 1, 88);
        }
        return snapshot(c);
    }

    function put(bytes memory b, uint256 p, int32 v) private pure returns (uint256) {
        assembly ("memory-safe") { mstore(add(add(b, 32), p), shl(224, v)) }
        return p + 4;
    }

    function snapshot(RenderContext memory c) private pure returns (bytes32) {
        bytes memory b = new bytes(68 + 4000 + 4 + uint256(c.visplaneCount) * 664 + 2560);
        int32[17] memory values = [
            c.ds.y,
            c.ds.x1,
            c.ds.x2,
            c.ds.xfrac,
            c.ds.yfrac,
            c.ds.xstep,
            c.ds.ystep,
            c.ds.colormap.length == 0 ? int32(-1) : int32(uint32(uint8(c.ds.colormap[0]) / 7)),
            c.dc.x,
            c.dc.yl,
            c.dc.yh,
            c.dc.iscale,
            c.dc.texturemid,
            c.dc.colormap.length == 0 ? int32(-1) : int32(uint32(uint8(c.dc.colormap[0]) / 7)),
            c.plane.basexscale,
            c.plane.baseyscale,
            c.plane.planeheight
        ];
        uint256 p;
        for (uint256 i; i < 17; ++i) {
            p = put(b, p, values[i]);
        }
        for (uint256 y; y < 200; ++y) {
            p = put(b, p, c.plane.cachedheight[y]);
            p = put(b, p, c.plane.cacheddistance[y]);
            p = put(b, p, c.plane.cachedxstep[y]);
            p = put(b, p, c.plane.cachedystep[y]);
            p = put(b, p, c.plane.spanstart[y]);
        }
        p = put(b, p, int32(c.visplaneCount));
        for (uint256 i; i < c.visplaneCount; ++i) {
            Visplane memory pl = c.visplanes[i];
            p = put(b, p, pl.height);
            p = put(b, p, int32(pl.picnum));
            p = put(b, p, pl.lightlevel);
            p = put(b, p, pl.minx);
            p = put(b, p, pl.maxx);
            for (uint256 x; x < 322; ++x) {
                b[p++] = pl.top[x];
            }
            for (uint256 x; x < 322; ++x) {
                b[p++] = pl.bottom[x];
            }
        }
        for (uint256 i; i < 2560; ++i) {
            b[p++] = c.rs.framebuffer[i];
        }
        require(p == b.length);
        return sha256(b);
    }

    function checkSynthetic(uint32 mode) private view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase2_planes/vectors.bin");
        string memory manifest = vm.readFile("test/fixtures/phase2_planes/manifest.json");
        require(
            sha256(data)
                == vm.parseBytes32(string.concat("0x", vm.parseJsonString(manifest, ".vectorsSha256")))
        );
        for (uint256 p; p < data.length; p += 72) {
            if (be32(data, p) != mode) continue;
            int32[10] memory a;
            for (uint256 i; i < 10; ++i) {
                a[i] = int32(be32(data, p + i * 4));
            }
            bytes32 expected;
            assembly ("memory-safe") { expected := mload(add(add(data, 72), p)) }
            bytes32 got = this.runVector(a);
            require(got == expected, vm.toString(p / 72));
        }
    }

    function testNativeMapCacheLighting() public view {
        checkSynthetic(0);
    }

    function testNativeMakeSpans() public view {
        checkSynthetic(1);
    }

    function testNativeDrawFlatSky() public view {
        checkSynthetic(2);
    }

    function testNativeConstructionRepeatedClear() public view {
        checkSynthetic(3);
    }

    function invalid(uint256 mode) external view {
        int32[10] memory a;
        a[5] = -1;
        RenderContext memory c = synthetic(a);
        if (mode == 0) R_Plane.R_MapPlane(c, -1, 0, 1);
        if (mode == 1) R_Plane.R_MapPlane(c, 8, 0, 1);
        if (mode == 2) R_Plane.R_MapPlane(c, 0, 2, 1);
        if (mode == 3) R_Plane.R_MapPlane(c, 0, 0, 8);
        if (mode == 4) R_Plane.R_MakeSpans(c, 9, 255, 0, 1, 2);
        if (mode == 5) R_Plane.R_MakeSpans(c, 1, 255, 0, -1, 2);
        if (mode == 6) R_Plane.R_CheckPlane(c, 0, 0, 1);
        if (mode == 7 || mode == 8) {
            for (uint32 i; i < 128; ++i) {
                R_Plane.R_FindPlane(c, int32(i), 0, 0);
            }
            if (mode == 7) {
                R_Plane.R_FindPlane(c, 128, 0, 0);
            } else {
                c.visplanes[0].minx = 0;
                c.visplanes[0].maxx = 1;
                c.visplanes[0].top[1] = 0x00;
                R_Plane.R_CheckPlane(c, 0, 0, 1);
            }
        }
        if (mode == 9 || mode == 10) {
            uint32 n = R_Plane.R_FindPlane(c, type(int32).min + 65536, 0, 0);
            c.visplanes[n].minx = mode == 9 ? int32(0) : int32(-1);
            c.visplanes[n].maxx = 1;
            R_Plane.R_DrawPlanes(c);
        }
    }

    function testBoundsAndUndefinedDomains() public view {
        for (uint256 mode; mode < 11; ++mode) {
            (bool ok, bytes memory result) = address(this).staticcall(abi.encodeCall(this.invalid, (mode)));
            require(!ok && result.length == 4, "expected named domain rejection");
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(result, 32)) }
            require(
                selector
                    == (mode == 7 || mode == 8
                            ? R_Plane.PlaneOverflow.selector
                            : R_Plane.PlaneBounds.selector)
            );
        }
    }
}
