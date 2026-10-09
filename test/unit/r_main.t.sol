// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_Main} from "../../src/doom/r_main.sol";
import {RenderState} from "../../src/doom/r_state.sol";
import {MapData, Node, Vertex, Seg, Subsector} from "../../src/doom/r_defs.sol";
import {GeometryVectors} from "../fixtures/phase2_geometry/GeometryVectors.sol";

contract RMainTest {
    event GeometryMetrics(
        uint256 blocks, uint256 detail, uint256 gasUsed, uint256 memoryBefore, uint256 memoryAfter
    );

    function word(bytes memory data, uint256 pos) private pure returns (uint32 v) {
        for (uint256 j; j < 4; ++j) {
            v = (v << 8) | uint8(data[pos + j]);
        }
    }

    function le16(bytes memory data, uint256 pos) private pure returns (uint16) {
        return uint16(uint8(data[pos])) | (uint16(uint8(data[pos + 1])) << 8);
    }

    function wadmap() private pure returns (MapData memory map) {
        bytes memory data = GeometryVectors.nodes();
        map.nodes = new Node[](data.length / 28);
        map.subsectors = new Subsector[](682);
        for (uint256 i; i < map.nodes.length; ++i) {
            Node memory n = map.nodes[i];
            uint256 p = i * 28;
            n.x = int32(int16(le16(data, p))) * 65536;
            n.y = int32(int16(le16(data, p + 2))) * 65536;
            n.dx = int32(int16(le16(data, p + 4))) * 65536;
            n.dy = int32(int16(le16(data, p + 6))) * 65536;
            n.children[0] = le16(data, p + 24);
            n.children[1] = le16(data, p + 26);
        }
    }

    function syntheticmap() private pure returns (MapData memory map) {
        map.nodes = new Node[](1);
        map.nodes[0].dy = 65536;
        map.nodes[0].children = [uint16(0x8000), uint16(0x8001)];
        map.subsectors = new Subsector[](2);
    }

    function testEveryOriginalGeometryVector() public pure {
        bytes memory data = GeometryVectors.vectors();
        MapData memory realmap = wadmap();
        MapData memory synth = syntheticmap();
        uint256 count;
        for (uint256 p; p < data.length;) {
            uint8 op = uint8(data[p]);
            uint8 scope = uint8(data[p + 1]);
            uint256 ni = uint8(data[p + 2]);
            uint256 no = uint8(data[p + 3]);
            p += 4;
            uint32[] memory a = new uint32[](ni);
            uint32[] memory e = new uint32[](no);
            for (uint256 i; i < ni; ++i) {
                a[i] = word(data, p);
                p += 4;
            }
            for (uint256 i; i < no; ++i) {
                e[i] = word(data, p);
                p += 4;
            }
            checkrow(op, a, e, scope == 1 ? realmap : synth);
            ++count;
        }
        require(count == 2380, "incomplete original geometry vectors");
    }

    function checkrow(uint8 op, uint32[] memory a, uint32[] memory e, MapData memory map) private pure {
        RenderState memory rs;
        if (op == 0) {
            require(
                R_Main.R_PointToAngle2(rs, int32(a[0]), int32(a[1]), int32(a[2]), int32(a[3])) == e[0],
                "angle"
            );
            require(rs.viewx == int32(a[0]) && rs.viewy == int32(a[1]), "angle mutation");
        } else if (op == 1) {
            Node memory n;
            n.x = int32(a[2]);
            n.y = int32(a[3]);
            n.dx = int32(a[4]);
            n.dy = int32(a[5]);
            require(R_Main.R_PointOnSide(int32(a[0]), int32(a[1]), n) == e[0], "node side");
        } else if (op == 2) {
            require(R_Main.R_PointInSubsector(int32(a[0]), int32(a[1]), map) == e[0], "subsector");
        } else if (op == 3) {
            uint32 n = uint32(map.nodes.length - 1);
            uint256 i;
            while ((n & 0x8000) == 0) {
                require(n == e[i++], "BSP node path");
                Node memory node = map.nodes[n];
                n = node.children[R_Main.R_PointOnSide(int32(a[0]), int32(a[1]), node)];
            }
            require(i + 1 == e.length && n == e[i], "BSP leaf path");
        } else if (op == 4) {
            rs.viewx = int32(a[0]);
            rs.viewy = int32(a[1]);
            require(uint32(R_Main.R_PointToDist(rs, int32(a[2]), int32(a[3]))) == e[0], "distance");
        } else if (op == 5) {
            MapData memory m;
            m.vertexes = new Vertex[](2);
            m.vertexes[0] = Vertex(int32(a[2]), int32(a[3]));
            m.vertexes[1] = Vertex(int32(a[4]), int32(a[5]));
            Seg memory seg;
            seg.v2 = 1;
            require(R_Main.R_PointOnSegSide(int32(a[0]), int32(a[1]), seg, m) == e[0], "seg side");
        } else if (op == 6) {
            rs.viewangle = a[0];
            rs.projection = int32(a[1]);
            rs.detailshift = uint8(a[2]);
            require(uint32(R_Main.R_ScaleFromGlobalAngle(rs, a[3], a[4], int32(a[5]))) == e[0], "scale");
        } else {
            require(op == 7);
            rs.validcount = 1;
            rs.framecount = 9;
            rs.sscount = 99;
            R_Main.R_SetupFrame(
                rs,
                int32(a[0]),
                int32(a[1]),
                int32(a[2]),
                a[3],
                int32(a[4]),
                a[5] == 0 ? int32(-1) : int32(a[5])
            );
            require(
                uint32(rs.viewx) == e[0] && uint32(rs.viewy) == e[1] && uint32(rs.viewz) == e[2]
                    && rs.viewangle == e[3],
                "camera"
            );
            require(
                uint32(rs.extralight) == e[4] && uint32(rs.viewsin) == e[5] && uint32(rs.viewcos) == e[6]
                    && uint32(rs.fixedcolormap) == e[7],
                "setup trig/light"
            );
            require(rs.framecount == e[8] && rs.validcount == e[9] && rs.sscount == e[10], "counters");
            for (uint256 i; i < 48; ++i) {
                require(
                    (rs.scalelightfixed.length == 0 ? type(uint32).max : uint32(uint8(rs.scalelightfixed[i])))
                        == e[11 + i],
                    "fixed light"
                );
            }
        }
    }

    function put(bytes memory out, uint256 index, uint32 value) private pure returns (uint256) {
        for (uint256 j; j < 4; ++j) {
            out[index * 4 + j] = bytes1(uint8(value >> (24 - j * 8)));
        }
        return index + 1;
    }

    function viewdump(RenderState memory r) private pure returns (bytes memory out) {
        uint256 size = 14 + 4096 + r.width + 1 + r.height + r.width + r.scaledviewwidth + r.height + r.width
            + 16 * 48 + 16 * 128;
        out = new bytes(size * 4);
        uint256 p;
        p = put(out, p, r.width);
        p = put(out, p, r.height);
        p = put(out, p, r.scaledviewwidth);
        p = put(out, p, r.detailshift);
        p = put(out, p, uint32(r.centerx));
        p = put(out, p, uint32(r.centery));
        p = put(out, p, uint32(r.centerxfrac));
        p = put(out, p, uint32(r.centeryfrac));
        p = put(out, p, uint32(r.projection));
        p = put(out, p, uint32(r.viewwindowx));
        p = put(out, p, uint32(r.viewwindowy));
        p = put(out, p, r.clipangle);
        p = put(out, p, uint32(r.pspritescale));
        p = put(out, p, uint32(r.pspriteiscale));
        for (uint256 i; i < 4096; ++i) {
            p = put(out, p, uint32(r.viewangletox[i]));
        }
        for (uint256 i; i <= r.width; ++i) {
            p = put(out, p, r.xtoviewangle[i]);
        }
        for (uint256 i; i < r.height; ++i) {
            p = put(out, p, uint32(r.yslope[i]));
        }
        for (uint256 i; i < r.width; ++i) {
            p = put(out, p, uint32(r.distscale[i]));
        }
        for (uint256 i; i < r.scaledviewwidth; ++i) {
            p = put(out, p, r.columnofs[i]);
        }
        for (uint256 i; i < r.height; ++i) {
            p = put(out, p, r.ylookup[i]);
        }
        for (uint256 i; i < r.width; ++i) {
            p = put(out, p, uint32(r.screenheightarray[i]));
        }
        for (uint256 i; i < 16 * 48; ++i) {
            p = put(out, p, uint8(r.scalelight[i]));
        }
        for (uint256 i; i < 16 * 128; ++i) {
            p = put(out, p, uint8(r.zlight[i]));
        }
        require(p == size);
    }

    function checkview(uint32 blocks, uint32 detail) private {
        RenderState memory r;
        uint256 beforeMemory;
        uint256 afterMemory;
        assembly ("memory-safe") { beforeMemory := mload(0x40) }
        uint256 g = gasleft();
        R_Main.R_InitLightTables(r);
        R_Main.R_ExecuteSetViewSize(r, blocks, detail);
        g -= gasleft();
        assembly ("memory-safe") { afterMemory := mload(0x40) }
        emit GeometryMetrics(blocks, detail, g, beforeMemory, afterMemory);
        require(
            sha256(viewdump(r)) == GeometryVectors.viewhash((blocks - 3) * 2 + detail),
            "whole native view arrays"
        );
    }

    function testNativeViewSize3Detail0() public {
        checkview(3, 0);
    }

    function testNativeViewSize3Detail1() public {
        checkview(3, 1);
    }

    function testNativeViewSize4Detail0() public {
        checkview(4, 0);
    }

    function testNativeViewSize4Detail1() public {
        checkview(4, 1);
    }

    function testNativeViewSize5Detail0() public {
        checkview(5, 0);
    }

    function testNativeViewSize5Detail1() public {
        checkview(5, 1);
    }

    function testNativeViewSize6Detail0() public {
        checkview(6, 0);
    }

    function testNativeViewSize6Detail1() public {
        checkview(6, 1);
    }

    function testNativeViewSize7Detail0() public {
        checkview(7, 0);
    }

    function testNativeViewSize7Detail1() public {
        checkview(7, 1);
    }

    function testNativeViewSize8Detail0() public {
        checkview(8, 0);
    }

    function testNativeViewSize8Detail1() public {
        checkview(8, 1);
    }

    function testNativeViewSize9Detail0() public {
        checkview(9, 0);
    }

    function testNativeViewSize9Detail1() public {
        checkview(9, 1);
    }

    function testNativeViewSize10Detail0() public {
        checkview(10, 0);
    }

    function testNativeViewSize10Detail1() public {
        checkview(10, 1);
    }

    function testNativeViewSize11Detail0() public {
        checkview(11, 0);
    }

    function testNativeViewSize11Detail1() public {
        checkview(11, 1);
    }

    function unsafeGeometry(uint8 op) external pure {
        RenderState memory r;
        if (op == 0) R_Main.R_PointToDist(r, 0, 0);
        if (op == 1) R_Main.R_PointToDist(r, type(int32).min, 0);
        if (op == 2) R_Main.R_PointToAngle(r, type(int32).min, 1);
        if (op == 3) R_Main.R_ScaleFromGlobalAngle(r, 0x80000000, 0, 65536);
        if (op == 4) R_Main.R_ExecuteSetViewSize(r, 2, 0);
        if (op == 5) R_Main.R_ExecuteSetViewSize(r, 12, 0);
        if (op == 6) R_Main.R_ExecuteSetViewSize(r, 11, 2);
        if (op == 7) R_Main.R_SetupFrame(r, 0, 0, 0, 0, 0, 34);
        if (op == 8) R_Main.R_InitTextureMapping(r);
        if (op >= 9) {
            MapData memory map = syntheticmap();
            if (op == 9) map.nodes[0].children = [uint16(0), uint16(0)];
            if (op == 10) map.nodes[0].children = [uint16(0x8002), uint16(0x8002)];
            if (op == 11) map.nodes[0].children = [uint16(2), uint16(2)];
            R_Main.R_PointInSubsector(0, 0, map);
        }
    }

    function testRejectUndefinedAndMalformedDomains() public view {
        for (uint8 i; i < 12; ++i) {
            bool failed;
            try this.unsafeGeometry(i) {}
            catch {
                failed = true;
            }
            require(failed, "invalid geometry accepted");
        }
    }

    function testZeroNodeSingleSubsector() public pure {
        MapData memory m;
        m.subsectors = new Subsector[](1);
        require(R_Main.R_PointInSubsector(123, -456, m) == 0);
    }

    function testSetupPreservesInactiveFixedLightArray() public pure {
        RenderState memory r;
        R_Main.R_SetupFrame(r, 0, 0, 0, 0, 0, 32);
        R_Main.R_SetupFrame(r, 0, 0, 0, 0, 0, -1);
        require(r.fixedcolormap == -1 && r.scalelightfixed[0] == bytes1(uint8(32)));
        require(r.framecount == 2 && r.validcount == 2);
    }

    function testLastRepresentableBSPNode() public pure {
        MapData memory m;
        m.nodes = new Node[](32768);
        m.subsectors = new Subsector[](1);
        m.nodes[32767].children = [uint16(0x8000), uint16(0x8000)];
        require(R_Main.R_PointInSubsector(0, 0, m) == 0);
    }

    function oversizedBSP() external pure {
        MapData memory m;
        m.nodes = new Node[](32769);
        m.subsectors = new Subsector[](1);
        R_Main.R_PointInSubsector(0, 0, m);
    }

    function testRejectUnrepresentableBSPRoot() public view {
        try this.oversizedBSP() {
            revert("oversized BSP accepted");
        } catch (bytes memory reason) {
            require(keccak256(reason) == keccak256(abi.encodeWithSelector(R_Main.InvalidBSP.selector)));
        }
    }
}
