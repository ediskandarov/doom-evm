// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_Data} from "../../src/doom/r_data.sol";
import {ResourceView, Texture, TexPatch, RenderResources, ColumnView} from "../../src/doom/r_data_types.sol";
import {ResourceIdentity, LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";
import {Vertex, Sector, Side, Line, Seg, Subsector, Node, MapData} from "../../src/doom/r_defs.sol";

interface DataVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
    function toString(uint256) external pure returns (string memory);
    function expectRevert() external;
}

contract DataHarness {
    function range(ResourceView memory v, uint32 p, uint32 n) external view returns (bytes memory) {
        return R_Data.read(v, p, n);
    }

    function composite(RenderResources memory r, uint32 n) external view returns (bytes memory) {
        R_Data.R_GenerateComposite(r, n);
        return r.textures[n].composite;
    }
}

contract RDataTest {
    DataVm constant vm = DataVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    event Measurement(string name, uint256 gasUsed, uint256 freeMemory);

    function rd(bytes memory b, uint256 p) internal pure returns (uint32) {
        return
            uint32(uint8(b[p])) | uint32(uint8(b[p + 1])) << 8 | uint32(uint8(b[p + 2])) << 16
                | uint32(uint8(b[p + 3])) << 24;
    }

    function wr(bytes memory b, uint256 p, uint32 n) internal pure {
        for (uint256 i; i < 4; i++) {
            b[p + i] = bytes1(uint8(n >> (i * 8)));
        }
    }

    function hashAt(bytes memory b, uint256 p) internal pure returns (bytes32 n) {
        require(p + 32 <= b.length);
        assembly ("memory-safe") { n := mload(add(add(b, 32), p)) }
    }

    function fixture(string memory name) internal view returns (bytes memory) {
        return vm.readFileBinary(string.concat("test/fixtures/phase2_data/", name));
    }

    function installChunk(uint256 i) external {
        bytes memory b =
            vm.readFileBinary(string.concat("artifacts/local/wad/phase2-chunks/", vm.toString(i), ".bin"));
        vm.etch(address(uint160(0x100000 + i)), b);
    }

    function setUp() public {
        for (uint256 i; i < 1755; i++) {
            this.installChunk(i);
        }
    }

    function source() internal view returns (ResourceView memory v) {
        v.byteLength = 28741889;
        v.chunks = new address[](1755);
        for (uint256 i; i < v.chunks.length; i++) {
            v.chunks[i] = address(uint160(0x100000 + i));
        }
        bytes memory dir = fixture("directory.bin");
        v.lumps = new LumpDescriptor[](dir.length / 16);
        for (uint256 i; i < v.lumps.length; i++) {
            bytes8 name;
            uint256 p = i * 16;
            assembly ("memory-safe") { name := mload(add(add(dir, 32), p)) }
            v.lumps[i] = LumpDescriptor(name, rd(dir, p + 8), rd(dir, p + 12));
        }
    }

    function init() internal returns (RenderResources memory r) {
        return initMode(false);
    }

    function initMode(bool lazy) internal returns (RenderResources memory r) {
        ResourceView memory v = source();
        uint256 start = gasleft();
        r = lazy ? R_Data.R_InitDataLazy(v) : R_Data.R_InitData(v);
        uint256 mem;
        assembly ("memory-safe") { mem := mload(0x40) }
        emit Measurement(lazy ? "R_InitDataLazy" : "R_InitData", start - gasleft(), mem);
    }

    function testResourceReadAcrossChunksAndOrdinaryDeploy() public {
        bytes memory a = new bytes(16384);
        for (uint256 i; i < a.length; i++) {
            a[i] = bytes1(uint8(i));
        }
        bytes memory b = hex"123456";
        ResourceView memory v;
        v.byteLength = 16387;
        v.chunks = new address[](2);
        v.chunks[0] = address(new ResourceStore(a));
        v.chunks[1] = address(new ResourceStore(b));
        require(keccak256(R_Data.read(v, 16382, 5)) == keccak256(hex"feff123456"));
        require(R_Data.read(v, 16387, 0).length == 0);
        DataHarness h = new DataHarness();
        vm.expectRevert();
        h.range(v, 16386, 2);
        vm.expectRevert();
        h.range(v, type(uint32).max, 1);
        v.chunks[1] = address(0);
        vm.expectRevert();
        h.range(v, 16384, 1);
    }

    function testNamesAndWidthMaskRules() public pure {
        ResourceView memory v;
        v.lumps = new LumpDescriptor[](4);
        v.lumps[0].name = "NAME";
        v.lumps[1].name = "name";
        v.lumps[2].name = hex"4e414d4500dead00";
        v.lumps[3].name = "OTHER";
        require(R_Data.W_CheckNumForName(v, "name") == 2);
        require(R_Data.W_CheckNumForName(v, "missing") == -1);
        RenderResources memory r;
        r.source = v;
        r.textures = new Texture[](3);
        r.textures[0].name = "NAME";
        r.textures[1].name = "name";
        r.textures[2].name = "OTHER";
        require(R_Data.R_CheckTextureNumForName(r, "name") == 0);
        require(R_Data.R_CheckTextureNumForName(r, "-none") == 0);
        require(R_Data.R_CheckTextureNumForName(r, "missing") == -1);
    }

    function testNativeAllLookupAndSpriteMetadata() public {
        RenderResources memory r = init();
        bytes memory expected = fixture("resources.bin");
        require(r.textures.length == rd(expected, 0));
        for (uint256 i; i < r.textures.length; i++) {
            Texture memory t = r.textures[i];
            uint256 p = 4 + i * 84;
            require(
                t.width == rd(expected, p) && t.height == rd(expected, p + 4)
                    && t.widthmask == rd(expected, p + 8) && t.compositesize == rd(expected, p + 12),
                "texture dimensions"
            );
            bytes memory lookup = new bytes(uint256(t.width) * 8);
            for (uint256 x; x < t.width; x++) {
                wr(lookup, x * 8, uint32(t.columnlump[x]));
                wr(lookup, x * 8 + 4, t.columnofs[x]);
            }
            require(sha256(lookup) == hashAt(expected, p + 16), "original lookup mismatch");
            require(rd(expected, p + 80) == 0, "native composite has holes");
        }
        uint256 tail = 4 + r.textures.length * 84;
        require(
            r.firstflat == rd(expected, tail) && r.numflats == rd(expected, tail + 4)
                && r.firstspritelump == rd(expected, tail + 8) && r.numspritelumps == rd(expected, tail + 12)
        );
        tail += 16;
        for (uint256 i; i < r.numspritelumps; i++) {
            require(
                uint32(r.spritewidth[i]) == rd(expected, tail)
                    && uint32(r.spriteoffset[i]) == rd(expected, tail + 4)
                    && uint32(r.spritetopoffset[i]) == rd(expected, tail + 8)
            );
            tail += 12;
        }
        require(tail == expected.length);
        require(r.colormaps.length == 8704);
        require(R_Data.R_GetFlat(r, 1).length == 4096);
    }

    function testNativeClippingIncludingNegativeOriginQuirk() public view {
        bytes memory expected = fixture("clip.bin");
        bytes memory patch = hex"0205000b16212c3700090300424d5800ff";
        uint256 p;
        for (int32 origin = -16; origin <= 16; origin++) {
            for (uint32 height = 1; height <= 20; height++) {
                bytes memory cache = new bytes(20);
                bytes memory written = new bytes(20);
                for (uint256 i; i < 20; i++) {
                    cache[i] = 0xa5;
                }
                R_Data.R_DrawColumnInCache(patch, 0, cache, written, 0, origin, height);
                for (uint256 i; i < 20; i++) {
                    require(cache[i] == expected[p++], "original cache clip mismatch");
                }
            }
        }
    }

    function testNativeRepresentativeCompositesAndDirectColumns() public {
        RenderResources memory r = initMode(true);
        bytes memory expected = fixture("resources.bin");
        uint32[12] memory ids = [uint32(0), 1, 7, 14, 20, 31, 570, 571, 862, 890, 961, 962];
        for (uint256 k; k < ids.length; k++) {
            uint32 i = ids[k];
            R_Data.R_GenerateLookup(r, i);
            Texture memory t = r.textures[i];
            if (t.compositesize > 0) {
                uint256 start = gasleft();
                R_Data.R_GenerateComposite(r, i);
                uint256 mem;
                assembly ("memory-safe") { mem := mload(0x40) }
                emit Measurement("R_GenerateComposite", start - gasleft(), mem);
                require(
                    sha256(t.composite) == hashAt(expected, 4 + uint256(i) * 84 + 48),
                    "original composite mismatch"
                );
            }
            for (uint32 j; j < 3; j++) {
                int32 col = j == 0 ? int32(-1) : j == 1 ? int32(0) : int32(uint32(t.width));
                uint32 c = uint32(col) & t.widthmask;
                ColumnView memory v = R_Data.R_GetColumn(r, i, col);
                require(v.offset == t.columnofs[c]);
                if (t.columnlump[c] > 0) {
                    require(
                        keccak256(v.data)
                            == keccak256(R_Data.W_CacheLumpNum(r.source, uint32(t.columnlump[c])))
                    );
                } else {
                    require(sha256(v.data) == hashAt(expected, 4 + uint256(i) * 84 + 48));
                }
            }
        }
    }

    function testAllComposites0() public {
        allComposites(0);
    }

    function testAllComposites1() public {
        allComposites(1);
    }

    function testAllComposites2() public {
        allComposites(2);
    }

    function testAllComposites3() public {
        allComposites(3);
    }

    function testAllComposites4() public {
        allComposites(4);
    }

    function testAllComposites5() public {
        allComposites(5);
    }

    function testAllComposites6() public {
        allComposites(6);
    }

    function testAllComposites7() public {
        allComposites(7);
    }

    function allComposites(uint32 shard) internal {
        RenderResources memory r = initMode(true);
        bytes memory expected = fixture("resources.bin");
        bytes memory columns = fixture("getcolumns.bin");
        for (uint32 i = shard; i < r.textures.length; i += 8) {
            uint256 p = 4 + uint256(i) * 84;
            for (uint32 j; j < 3; j++) {
                int32 column = j == 0 ? int32(-1) : j == 1 ? int32(0) : int32(uint32(r.textures[i].width));
                ColumnView memory c = R_Data.R_GetColumn(r, i, column);
                int32 lump = int32(rd(columns, uint256(i) * 24 + j * 8));
                require(c.offset == rd(columns, uint256(i) * 24 + j * 8 + 4), "native R_GetColumn offset");
                require(
                    r.textures[i].columnlump[uint32(column) & r.textures[i].widthmask] == lump,
                    "native R_GetColumn lump"
                );
                bytes memory data = c.data;
                bytes memory target = lump > 0 ? r.lumpcache[uint32(lump)] : r.textures[i].composite;
                bool same;
                assembly ("memory-safe") { same := eq(data, target) }
                require(same, "native R_GetColumn branch");
            }
            if (rd(expected, p + 12) == 0) continue;
            if (!r.textures[i].compositeReady) R_Data.R_GenerateComposite(r, i);
            require(
                sha256(r.textures[i].composite) == hashAt(expected, p + 48), "all native composites mismatch"
            );
        }
    }

    function testLazyCacheReuseAndFlatAccessCosts() public {
        RenderResources memory r = initMode(true);
        uint256 start = gasleft();
        ColumnView memory a = R_Data.R_GetColumn(r, 2, 0);
        uint256 first = start - gasleft();
        start = gasleft();
        ColumnView memory b = R_Data.R_GetColumn(r, 2, 1);
        uint256 second = start - gasleft();
        uint256 mem;
        assembly ("memory-safe") { mem := mload(0x40) }
        emit Measurement("direct column uncached", first, mem);
        emit Measurement("direct column cached", second, mem);
        bytes memory ad = a.data;
        bytes memory bd = b.data;
        bool same;
        assembly ("memory-safe") { same := eq(ad, bd) }
        require(same, "cache did not reuse allocation");
        start = gasleft();
        bytes memory flat = R_Data.R_GetFlat(r, 1);
        uint256 flatGas = start - gasleft();
        assembly ("memory-safe") { mem := mload(0x40) }
        emit Measurement("flat uncached", flatGas, mem);
        start = gasleft();
        bytes memory again = R_Data.R_GetFlat(r, 1);
        flatGas = start - gasleft();
        assembly ("memory-safe") { mem := mload(0x40) }
        emit Measurement("flat cached", flatGas, mem);
        assembly ("memory-safe") { same := eq(flat, again) }
        require(same);
    }

    function testCompositeHolesRejected() public {
        // A one-pixel patch; composite cache height two leaves row one undefined in original C.
        bytes memory patch = hex"01000200000000000c0000000001007700ff";
        ResourceView memory v;
        v.byteLength = uint32(patch.length);
        v.chunks = new address[](1);
        v.chunks[0] = address(new ResourceStore(patch));
        v.lumps = new LumpDescriptor[](2);
        v.lumps[1] = LumpDescriptor("PATCH", 0, uint32(patch.length));
        RenderResources memory r;
        r.source = v;
        r.textures = new Texture[](1);
        Texture memory t = r.textures[0];
        t.width = 1;
        t.height = 2;
        t.patches = new TexPatch[](2);
        t.patches[0] = TexPatch(0, 0, 1);
        t.patches[1] = TexPatch(0, 0, 1);
        DataHarness h = new DataHarness();
        vm.expectRevert();
        h.composite(r, 0);
        t.height = 1;
        R_Data.R_GenerateComposite(r, 0);
        require(t.composite.length == 1 && t.composite[0] == 0x77);
    }

    function check(bytes memory b, uint256 p, uint32 value) internal pure returns (uint256) {
        require(rd(b, p) == value, "original map field mismatch");
        return p + 4;
    }

    function testNativeAllE1M1MapFields() public {
        RenderResources memory r = initMode(true);
        uint256 start = gasleft();
        MapData memory m = R_Data.R_LoadMap(r, "E1M1");
        uint256 mem;
        assembly ("memory-safe") { mem := mload(0x40) }
        emit Measurement("R_LoadMap", start - gasleft(), mem);
        bytes memory e = fixture("map.bin");
        uint256 p = check(e, 0, uint32(m.vertexes.length));
        for (uint256 i; i < m.vertexes.length; i++) {
            p = check(e, p, uint32(m.vertexes[i].x));
            p = check(e, p, uint32(m.vertexes[i].y));
        }
        p = check(e, p, uint32(m.sectors.length));
        for (uint256 i; i < m.sectors.length; i++) {
            Sector memory s = m.sectors[i];
            p = check(e, p, uint32(s.floorheight));
            p = check(e, p, uint32(s.ceilingheight));
            p = check(e, p, s.floorpic);
            p = check(e, p, s.ceilingpic);
            p = check(e, p, uint32(int32(s.lightlevel)));
        }
        p = check(e, p, uint32(m.sides.length));
        for (uint256 i; i < m.sides.length; i++) {
            Side memory s = m.sides[i];
            p = check(e, p, uint32(s.textureoffset));
            p = check(e, p, uint32(s.rowoffset));
            p = check(e, p, s.toptexture);
            p = check(e, p, s.bottomtexture);
            p = check(e, p, s.midtexture);
            p = check(e, p, s.sector);
        }
        p = check(e, p, uint32(m.lines.length));
        for (uint256 i; i < m.lines.length; i++) {
            Line memory l = m.lines[i];
            p = check(e, p, l.v1);
            p = check(e, p, l.v2);
            p = check(e, p, uint32(l.dx));
            p = check(e, p, uint32(l.dy));
            p = check(e, p, l.flags);
            p = check(e, p, uint32(int32(l.special)));
            p = check(e, p, uint32(int32(l.tag)));
            p = check(e, p, l.sidenum[0]);
            p = check(e, p, l.sidenum[1]);
            for (uint256 j; j < 4; j++) {
                p = check(e, p, uint32(l.bbox[j]));
            }
            p = check(e, p, l.slopetype);
            p = check(e, p, l.frontsector);
            p = check(e, p, l.backsector);
        }
        p = check(e, p, uint32(m.segs.length));
        for (uint256 i; i < m.segs.length; i++) {
            Seg memory s = m.segs[i];
            p = check(e, p, s.v1);
            p = check(e, p, s.v2);
            p = check(e, p, uint32(s.offset));
            p = check(e, p, s.angle);
            p = check(e, p, s.sidedef);
            p = check(e, p, s.linedef);
            p = check(e, p, s.frontsector);
            p = check(e, p, s.backsector);
        }
        p = check(e, p, uint32(m.subsectors.length));
        for (uint256 i; i < m.subsectors.length; i++) {
            Subsector memory s = m.subsectors[i];
            p = check(e, p, s.sector);
            p = check(e, p, s.numlines);
            p = check(e, p, s.firstline);
        }
        p = check(e, p, uint32(m.nodes.length));
        for (uint256 i; i < m.nodes.length; i++) {
            Node memory n = m.nodes[i];
            p = check(e, p, uint32(n.x));
            p = check(e, p, uint32(n.y));
            p = check(e, p, uint32(n.dx));
            p = check(e, p, uint32(n.dy));
            for (uint256 j; j < 2; j++) {
                for (uint256 k; k < 4; k++) {
                    p = check(e, p, uint32(n.bbox[j][k]));
                }
            }
            p = check(e, p, n.children[0]);
            p = check(e, p, n.children[1]);
        }
        require(p == e.length);
        require(m.things.length == 292);
    }
}
