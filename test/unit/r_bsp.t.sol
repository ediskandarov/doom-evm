// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_BSP} from "../../src/doom/r_bsp.sol";
import {InstrumentedR_BSP} from "../fixtures/phase2_bsp/InstrumentedR_BSP.sol";
import {R_Main} from "../../src/doom/r_main.sol";
import {R_Plane} from "../../src/doom/r_plane.sol";
import {R_Data} from "../../src/doom/r_data.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {RenderContext, ClipRange} from "../../src/doom/r_render_state.sol";
import {Node, Subsector, Sector, Seg, Vertex, Side, Line} from "../../src/doom/r_defs.sol";

interface BspVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
}

contract RBspTest {
    BspVm constant vm = BspVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event BspMetrics(
        uint256 angle, uint256 initGas, uint256 productionGas, uint256 instrumentedGas, uint256 allocatorAfter
    );

    function be32(bytes memory b, uint256 p) internal pure returns (uint32 v) {
        for (uint256 j; j < 4; ++j) {
            v = (v << 8) | uint8(b[p + j]);
        }
    }

    function le32(bytes memory b, uint256 p) internal pure returns (uint32 v) {
        for (uint256 j; j < 4; ++j) {
            v |= uint32(uint8(b[p + j])) << uint32(j * 8);
        }
    }

    function put32(bytes memory b, uint256 p, uint32 v) internal pure {
        for (uint256 j; j < 4; ++j) {
            b[p + j] = bytes1(uint8(v >> (24 - j * 8)));
        }
    }

    function installChunk(uint256 i) external {
        bytes memory b =
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"));
        vm.etch(address(uint160(0x100000 + i)), b);
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

    function store(RenderContext memory c, int32 first, int32 last) internal pure {
        uint256 p = 30000 + uint256(c.rs.framecount) * 24;
        require(p + 24 <= c.rs.framebuffer.length);
        put32(c.rs.framebuffer, p, uint32(first));
        put32(c.rs.framebuffer, p + 4, uint32(last));
        put32(c.rs.framebuffer, p + 8, c.curline);
        put32(c.rs.framebuffer, p + 12, c.frontsector);
        put32(c.rs.framebuffer, p + 16, c.backsector);
        put32(c.rs.framebuffer, p + 20, c.wall.rw_angle1);
        ++c.rs.framecount;
    }

    function sprites(RenderContext memory c, uint32 sector) internal pure {
        uint256 p = 50000 + uint256(c.rs.validcount) * 4;
        require(p + 4 <= c.rs.framebuffer.length);
        put32(c.rs.framebuffer, p, sector);
        ++c.rs.validcount;
    }
    function noStore(RenderContext memory, int32, int32) internal pure {}
    function noSprites(RenderContext memory, uint32) internal pure {}

    function reset(RenderContext memory c) private pure {
        R_BSP.R_ClearClipSegs(c);
        R_BSP.R_ClearDrawSegs(c);
        R_Plane.R_ClearPlanes(c);
        c.rs.framecount = 0;
        c.rs.validcount = 0;
        c.rs.sscount = 0;
        c.rs.fuzzpos = 0;
        c.curline = 0;
        c.frontsector = 0;
        c.backsector = 0;
        c.wall.rw_angle1 = 0;
        c.rs.framebuffer = new bytes(64000);
    }

    function observedState(RenderContext memory c) private pure returns (bytes32) {
        bytes memory callbacks = new bytes(uint256(c.rs.framecount) * 24 + uint256(c.rs.validcount) * 4);
        for (uint256 i; i < uint256(c.rs.framecount) * 24; ++i) {
            callbacks[i] = c.rs.framebuffer[30000 + i];
        }
        for (uint256 i; i < uint256(c.rs.validcount) * 4; ++i) {
            callbacks[uint256(c.rs.framecount) * 24 + i] = c.rs.framebuffer[50000 + i];
        }
        ClipRange[] memory live = new ClipRange[](c.solidsegCount);
        for (uint256 i; i < c.solidsegCount; ++i) {
            live[i] = c.solidsegs[i];
        }
        return keccak256(
            abi.encode(
                callbacks,
                live,
                c.curline,
                c.frontsector,
                c.backsector,
                c.wall.rw_angle1,
                c.rs.sscount,
                c.floorplane,
                c.ceilingplane,
                c.visplaneCount,
                c.visplanes,
                c.drawsegCount,
                c.floorclip,
                c.ceilingclip
            )
        );
    }

    function checkTrace(uint256 angle) private {
        uint256 start = gasleft();
        RenderContext memory c;
        c.resources = R_Data.R_InitDataLazy(source());
        c.map = R_Data.R_LoadMap(c.resources, "E1M1");
        c.skyflatnum = R_Data.R_FlatNumForName(c.resources, "F_SKY1");
        R_Main.R_ExecuteSetViewSize(c.rs, 11, 0);
        R_Main.R_SetupFrame(c.rs, -27262976, 16777216, 2686976, uint32(angle * 0x20000000), 0, -1);
        uint256 initGas = start - gasleft();
        reset(c);
        start = gasleft();
        R_BSP.R_RenderBSPNode(c, int32(uint32(c.map.nodes.length - 1)), store, sprites);
        uint256 productionGas = start - gasleft();
        bytes32 production = observedState(c);
        reset(c);
        start = gasleft();
        InstrumentedR_BSP.R_RenderBSPNode(c, int32(uint32(c.map.nodes.length - 1)), store, sprites);
        uint256 instrumentedGas = start - gasleft();
        require(observedState(c) == production, "production/instrumented context mismatch");
        bytes memory trace = vm.readFileBinary(
            string.concat("test/fixtures/phase2_bsp/full-angle", vm.toString(angle), ".bin")
        );
        require(c.rs.fuzzpos == trace.length, "native trace length");
        for (uint256 i; i < trace.length; ++i) {
            require(c.rs.framebuffer[i] == trace[i], "native ordered BSP trace");
        }
        uint256 allocator;
        assembly ("memory-safe") { allocator := mload(0x40) }
        emit BspMetrics(angle, initGas, productionGas, instrumentedGas, allocator);
    }

    function testOriginalE1M1Angle0Trace() public {
        checkTrace(0);
    }

    function testOriginalE1M1Angle1Trace() public {
        checkTrace(1);
    }

    function testOriginalE1M1Angle2Trace() public {
        checkTrace(2);
    }

    function testOriginalE1M1Angle3Trace() public {
        checkTrace(3);
    }

    function testOriginalE1M1Angle4Trace() public {
        checkTrace(4);
    }

    function testOriginalE1M1Angle5Trace() public {
        checkTrace(5);
    }

    function testOriginalE1M1Angle6Trace() public {
        checkTrace(6);
    }

    function testOriginalE1M1Angle7Trace() public {
        checkTrace(7);
    }

    function testEveryNativeClipOperation() public view {
        RenderContext memory c;
        c.rs.framebuffer = new bytes(64000);
        bytes memory data = vm.readFileBinary("test/fixtures/phase2_bsp/clip.bin");
        uint256 p;
        uint256 rows;
        while (p < data.length) {
            uint8 op = uint8(data[p]);
            int32 a = int32(be32(data, p + 1));
            int32 b = int32(be32(data, p + 5));
            uint256 ranges = uint8(data[p + 9]);
            uint256 clips = uint8(data[p + 10]);
            p += 11;
            c.rs.framecount = 0;
            if (op == 0) {
                c.rs.width = uint16(uint32(a));
                R_BSP.R_ClearClipSegs(c);
            } else if (op == 1) {
                R_BSP.R_ClipSolidWallSegment(c, a, b, store);
            } else {
                require(op == 2);
                R_BSP.R_ClipPassWallSegment(c, a, b, store);
            }
            require(c.rs.framecount == ranges && c.solidsegCount == clips, "native clip count");
            for (uint256 i; i < ranges; ++i) {
                require(
                    be32(c.rs.framebuffer, 30000 + i * 24) == be32(data, p)
                        && be32(c.rs.framebuffer, 30004 + i * 24) == be32(data, p + 4),
                    "native clip fragment"
                );
                p += 8;
            }
            for (uint256 i; i < clips; ++i) {
                require(
                    uint32(c.solidsegs[i].first) == be32(data, p)
                        && uint32(c.solidsegs[i].last) == be32(data, p + 4),
                    "native clip list"
                );
                p += 8;
            }
            ++rows;
        }
        require(rows == 1045, "incomplete native clip fixture");
    }

    function tinyContext() private pure returns (RenderContext memory c) {
        c.rs.width = 320;
        c.rs.height = 200;
        c.rs.centerxfrac = 160 * 65536;
        c.rs.viewz = 41 * 65536;
        c.skyflatnum = 99;
        c.map.subsectors = new Subsector[](1);
        c.map.sectors = new Sector[](1);
        c.map.sectors[0].ceilingheight = 128 * 65536;
        reset(c);
    }

    function bounds(Node memory n) private pure {
        n.bbox[0] = [int32(65536), -65536, -65536, 65536];
        n.bbox[1] = n.bbox[0];
    }

    function testZeroNodeAndLeafFlags() public view {
        RenderContext memory c = tinyContext();
        R_BSP.R_RenderBSPNode(c, -1, noStore, noSprites);
        require(c.rs.sscount == 1);
        R_BSP.R_RenderBSPNode(c, 0x8000, noStore, noSprites);
        require(c.rs.sscount == 2);
    }

    function testDAGRevisitsNodesAfterLeavingActivePath() public view {
        RenderContext memory c = tinyContext();
        c.map.nodes = new Node[](2);
        bounds(c.map.nodes[0]);
        bounds(c.map.nodes[1]);
        c.map.nodes[0].children = [uint16(0x8000), uint16(0x8000)];
        c.map.nodes[1].children = [uint16(0), uint16(0)];
        R_BSP.R_RenderBSPNode(c, 1, noStore, noSprites);
        require(c.rs.sscount == 4, "valid DAG was suppressed");
    }

    function malformed(uint8 op) external view {
        RenderContext memory c = tinyContext();
        if (op == 0) {
            R_BSP.R_ClipSolidWallSegment(c, -1, 0, noStore);
            return;
        }
        if (op == 1) {
            R_BSP.R_ClipPassWallSegment(c, 0, 320, noStore);
            return;
        }
        if (op == 2) {
            R_BSP.R_ClipSolidWallSegment(c, 20, 19, noStore);
            return;
        }
        if (op == 3) {
            for (int32 x = 1; x < 100; x += 3) {
                R_BSP.R_ClipSolidWallSegment(c, x, x, noStore);
            }
            return;
        }
        if (op == 4) {
            R_BSP.R_RenderBSPNode(c, 0x8001, noStore, noSprites);
            return;
        }
        if (op == 5) {
            R_BSP.R_RenderBSPNode(c, -2, noStore, noSprites);
            return;
        }
        c.map.nodes = new Node[](2);
        bounds(c.map.nodes[0]);
        bounds(c.map.nodes[1]);
        c.map.nodes[0].children = [uint16(1), uint16(1)];
        c.map.nodes[1].children = [uint16(0), uint16(0)];
        if (op == 7) c.map.nodes[0].children = [uint16(2), uint16(2)];
        R_BSP.R_RenderBSPNode(c, 0, noStore, noSprites);
    }

    function testBoundsClipCapacityAndTraversedCycles() public view {
        for (uint8 op; op < 8; ++op) {
            bool failed;
            try this.malformed(op) {}
            catch {
                failed = true;
            }
            require(failed, "invalid BSP input accepted");
        }
    }

    function testSubsectorPlanesHeightAndSky() public view {
        RenderContext memory c = tinyContext();
        R_BSP.R_Subsector(c, 0, noStore, noSprites);
        require(c.floorplane != type(uint32).max && c.ceilingplane != type(uint32).max);
        c.map.sectors[0].floorheight = c.rs.viewz;
        c.map.sectors[0].ceilingheight = c.rs.viewz;
        R_BSP.R_Subsector(c, 0, noStore, noSprites);
        require(c.floorplane == type(uint32).max && c.ceilingplane == type(uint32).max);
        c.map.sectors[0].ceilingpic = c.skyflatnum;
        R_BSP.R_Subsector(c, 0, noStore, noSprites);
        require(c.ceilingplane != type(uint32).max && c.visplanes[c.ceilingplane].height == 0);
    }

    function testSingleSidedWindowClosedAndEmptyLines() public view {
        RenderContext memory c = tinyContext();
        R_Main.R_ExecuteSetViewSize(c.rs, 11, 0);
        c.rs.viewangle = 0;
        c.map.vertexes = new Vertex[](2);
        c.map.vertexes[0] = Vertex(128 * 65536, 128 * 65536);
        c.map.vertexes[1] = Vertex(128 * 65536, -128 * 65536);
        c.map.sectors = new Sector[](2);
        c.map.sectors[0].ceilingheight = 128 * 65536;
        c.map.sectors[1].ceilingheight = 128 * 65536;
        c.map.sides = new Side[](1);
        c.map.segs = new Seg[](1);
        c.map.segs[0].v2 = 1;
        c.map.segs[0].backsector = type(uint32).max;
        R_BSP.R_AddLine(c, 0, store);
        require(c.rs.framecount == 1 && c.solidsegCount == 2, "single sided not solid");
        R_BSP.R_ClearClipSegs(c);
        c.rs.framecount = 0;
        c.map.segs[0].backsector = 1;
        R_BSP.R_AddLine(c, 0, store);
        require(c.rs.framecount == 0, "empty identical line drawn");
        c.map.sides[0].midtexture = 1;
        R_BSP.R_AddLine(c, 0, store);
        require(c.rs.framecount == 1 && c.solidsegCount == 2, "masked equal-height window");
        c.map.sides[0].midtexture = 0;
        c.map.sectors[1].floorheight = 32 * 65536;
        c.rs.framecount = 0;
        R_BSP.R_AddLine(c, 0, store);
        require(c.rs.framecount == 1 && c.solidsegCount == 2, "height-changing window");
        c.map.sectors[1].ceilingheight = 0;
        c.rs.framecount = 0;
        R_BSP.R_AddLine(c, 0, store);
        require(c.rs.framecount == 1 && c.solidsegCount == 2, "closed door");
        R_BSP.R_ClearClipSegs(c);
        c.rs.framecount = 0;
        c.map.segs[0].v1 = 1;
        c.map.segs[0].v2 = 0;
        R_BSP.R_AddLine(c, 0, store);
        require(c.rs.framecount == 0, "backface rendered");
    }

    function testClipMergingPreservesIndependentMemorySlots() public view {
        RenderContext memory c = tinyContext();
        R_BSP.R_ClipSolidWallSegment(c, 100, 110, noStore);
        R_BSP.R_ClipSolidWallSegment(c, 20, 30, noStore);
        R_BSP.R_ClipSolidWallSegment(c, 60, 70, noStore);
        require(c.solidsegCount == 5 && c.solidsegs[2].first == 60 && c.solidsegs[3].first == 100);
        R_BSP.R_ClipSolidWallSegment(c, 25, 105, noStore);
        require(c.solidsegCount == 4 && c.solidsegs[1].first == 20 && c.solidsegs[1].last == 110);
    }

    function testDeepValidTreeUsesExplicitStack() public view {
        RenderContext memory c = tinyContext();
        c.map.nodes = new Node[](1024);
        for (uint32 i; i < 1024; ++i) {
            bounds(c.map.nodes[i]);
            c.map.nodes[i].children = [i == 0 ? uint16(0x8000) : uint16(i - 1), uint16(0x8000)];
        }
        R_BSP.R_RenderBSPNode(c, 1023, noStore, noSprites);
        require(c.rs.sscount == 1025, "deep original traversal order lost");
    }
}
