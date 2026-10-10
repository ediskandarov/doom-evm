// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {R_Data} from "../doom/r_data.sol";
import {ResourceView, RenderResources} from "../doom/r_data_types.sol";
import {MapData, Sector, Side, Line, Seg, Subsector, Node} from "../doom/r_defs.sol";

/// @notice Goal 4.7a resource-only verification harness; never used by production adapters.
contract EpisodeResourcesProbe {
    event ResourceProof(
        bytes8 indexed map, bytes32 geometry, bytes32 things, bytes32 blockmap, bytes32 reject
    );

    function put(bytes memory b, uint256 p, uint32 n) private pure returns (uint256) {
        for (uint256 i; i < 4; ++i) {
            b[p + i] = bytes1(uint8(n >> (i * 8)));
        }
        return p + 4;
    }

    function geometry(MapData memory m) private pure returns (bytes32) {
        uint256 length = 7 + m.vertexes.length * 2 + m.sectors.length * 5 + m.sides.length * 6
            + m.lines.length * 16 + m.segs.length * 8 + m.subsectors.length * 3 + m.nodes.length * 14;
        bytes memory e = new bytes(length * 4);
        uint256 p = put(e, 0, uint32(m.vertexes.length));
        for (uint256 i; i < m.vertexes.length; i++) {
            p = put(e, p, uint32(m.vertexes[i].x));
            p = put(e, p, uint32(m.vertexes[i].y));
        }
        p = put(e, p, uint32(m.sectors.length));
        for (uint256 i; i < m.sectors.length; i++) {
            Sector memory s = m.sectors[i];
            p = put(e, p, uint32(s.floorheight));
            p = put(e, p, uint32(s.ceilingheight));
            p = put(e, p, s.floorpic);
            p = put(e, p, s.ceilingpic);
            p = put(e, p, uint32(int32(s.lightlevel)));
        }
        p = put(e, p, uint32(m.sides.length));
        for (uint256 i; i < m.sides.length; i++) {
            Side memory s = m.sides[i];
            p = put(e, p, uint32(s.textureoffset));
            p = put(e, p, uint32(s.rowoffset));
            p = put(e, p, s.toptexture);
            p = put(e, p, s.bottomtexture);
            p = put(e, p, s.midtexture);
            p = put(e, p, s.sector);
        }
        p = put(e, p, uint32(m.lines.length));
        for (uint256 i; i < m.lines.length; i++) {
            Line memory l = m.lines[i];
            p = put(e, p, l.v1);
            p = put(e, p, l.v2);
            p = put(e, p, uint32(l.dx));
            p = put(e, p, uint32(l.dy));
            p = put(e, p, l.flags);
            p = put(e, p, uint32(int32(l.special)));
            p = put(e, p, uint32(int32(l.tag)));
            p = put(e, p, l.sidenum[0]);
            p = put(e, p, l.sidenum[1]);
            for (uint256 j; j < 4; j++) {
                p = put(e, p, uint32(l.bbox[j]));
            }
            p = put(e, p, l.slopetype);
            p = put(e, p, l.frontsector);
            p = put(e, p, l.backsector);
        }
        p = put(e, p, uint32(m.segs.length));
        for (uint256 i; i < m.segs.length; i++) {
            Seg memory s = m.segs[i];
            p = put(e, p, s.v1);
            p = put(e, p, s.v2);
            p = put(e, p, uint32(s.offset));
            p = put(e, p, s.angle);
            p = put(e, p, s.sidedef);
            p = put(e, p, s.linedef);
            p = put(e, p, s.frontsector);
            p = put(e, p, s.backsector);
        }
        p = put(e, p, uint32(m.subsectors.length));
        for (uint256 i; i < m.subsectors.length; i++) {
            Subsector memory s = m.subsectors[i];
            p = put(e, p, s.sector);
            p = put(e, p, s.numlines);
            p = put(e, p, s.firstline);
        }
        p = put(e, p, uint32(m.nodes.length));
        for (uint256 i; i < m.nodes.length; i++) {
            Node memory n = m.nodes[i];
            p = put(e, p, uint32(n.x));
            p = put(e, p, uint32(n.y));
            p = put(e, p, uint32(n.dx));
            p = put(e, p, uint32(n.dy));
            for (uint256 j; j < 2; j++) {
                for (uint256 k; k < 4; k++) {
                    p = put(e, p, uint32(n.bbox[j][k]));
                }
            }
            p = put(e, p, n.children[0]);
            p = put(e, p, n.children[1]);
        }
        require(p == e.length, "geometry transcript length");
        return sha256(e);
    }

    function load(ResourceView memory v, bytes8 map) external returns (uint256 initGas, uint256 mapGas) {
        require(map >= bytes8("E1M1") && map <= bytes8("E1M9"), "Episode One only");
        uint256 start = gasleft();
        RenderResources memory r = R_Data.R_InitDataLazy(v);
        initGas = start - gasleft();
        start = gasleft();
        MapData memory m = R_Data.R_LoadMap(r, map);
        mapGas = start - gasleft();
        bytes memory things = new bytes((1 + m.things.length * 5) * 4);
        uint256 p = put(things, 0, uint32(m.things.length));
        for (uint256 i; i < m.things.length; ++i) {
            p = put(things, p, uint32(int32(m.things[i].x)));
            p = put(things, p, uint32(int32(m.things[i].y)));
            p = put(things, p, uint32(int32(m.things[i].angle)));
            p = put(things, p, uint32(int32(m.things[i].thingType)));
            p = put(things, p, uint32(int32(m.things[i].options)));
        }
        uint32 base = R_Data.W_GetNumForName(v, map);
        bytes memory bm = R_Data.W_CacheLumpNum(v, base + 10);
        require(bm.length >= 8 && bm.length % 2 == 0, "blockmap length");
        bytes memory blockmap = new bytes((4 + bm.length / 2) * 4);
        p = 0;
        for (uint256 i; i < 4; ++i) {
            p = put(blockmap, p, uint32(word16(bm, i * 2) * (i < 2 ? int32(65536) : int32(1))));
        }
        for (uint256 i; i < bm.length / 2; ++i) {
            p = put(blockmap, p, uint32(word16(bm, i * 2)));
        }
        emit ResourceProof(
            map, geometry(m), sha256(things), sha256(blockmap), sha256(R_Data.W_CacheLumpNum(v, base + 9))
        );
    }

    function word16(bytes memory b, uint256 p) private pure returns (int32) {
        return int32(int16(uint16(uint8(b[p])) | uint16(uint8(b[p + 1])) << 8));
    }
}
