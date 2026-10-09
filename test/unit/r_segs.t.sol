// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_BSP} from "../../src/doom/r_bsp.sol";
import {R_Main} from "../../src/doom/r_main.sol";
import {R_Plane} from "../../src/doom/r_plane.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {R_Segs} from "../../src/doom/r_segs.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
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
}
