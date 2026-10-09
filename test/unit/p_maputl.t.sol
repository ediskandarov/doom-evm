// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {P_MapUtl as U} from "../../src/doom/p_maputl.sol";
import {P_Sight} from "../../src/doom/p_sight.sol";
import {GameContext, DivLine, GameConst as C, Mobj, GameSector} from "../../src/doom/p_game_state.sol";
import {Vertex, Line, Sector, Subsector, MapData} from "../../src/doom/r_defs.sol";

interface VmMapUtl {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract P_MapUtl_Test {
    VmMapUtl constant vm = VmMapUtl(address(uint160(uint256(keccak256("hevm cheat code")))));

    function word(bytes memory data, uint256 p) private pure returns (uint32 n) {
        for (uint256 i; i < 4; i++) {
            n = (n << 8) | uint8(data[p + i]);
        }
    }

    function testEveryOriginalCollisionGeometryVector() public view {
        bytes memory data = vm.readFileBinary("test/fixtures/phase3_map/geometry.bin");
        uint256 count = word(data, 0);
        uint256 p = 4;
        require(count == 4310, "native case count");
        GameContext memory c;
        c.map.vertexes = new Vertex[](1);
        c.map.lines = new Line[](1);
        c.map.sectors = new Sector[](2);
        for (uint256 row; row < count; row++) {
            uint8 op = uint8(data[p]);
            uint256 ni = uint8(data[p + 1]);
            uint256 no = uint8(data[p + 2]);
            p += 4;
            int32[] memory a = new int32[](ni);
            int32[] memory e = new int32[](no);
            for (uint256 i; i < ni; i++) {
                a[i] = int32(word(data, p));
                p += 4;
            }
            for (uint256 i; i < no; i++) {
                e[i] = int32(word(data, p));
                p += 4;
            }
            int32 got;
            if (op == 0) {
                got = U.P_AproxDistance(a[0], a[1]);
            } else if (op == 1) {
                c.map.vertexes[0] = Vertex(a[2], a[3]);
                c.map.lines[0].dx = a[4];
                c.map.lines[0].dy = a[5];
                got = U.P_PointOnLineSide(a[0], a[1], c.map.lines[0], c.map);
            } else if (op == 2) {
                c.map.vertexes[0] = Vertex(a[4], a[5]);
                c.map.lines[0].dx = a[6];
                c.map.lines[0].dy = a[7];
                c.map.lines[0].slopetype = uint8(uint32(a[8]));
                int32[4] memory box = [a[0], a[1], a[2], a[3]];
                got = U.P_BoxOnLineSide(box, c.map.lines[0], c.map);
            } else if (op == 3 || op == 5) {
                DivLine memory dl = DivLine(a[2], a[3], a[4], a[5]);
                got = op == 3 ? U.P_PointOnDivlineSide(a[0], a[1], dl) : P_Sight.P_DivlineSide(a[0], a[1], dl);
            } else if (op == 4 || op == 6) {
                DivLine memory d1 = DivLine(a[0], a[1], a[2], a[3]);
                DivLine memory d2 = DivLine(a[4], a[5], a[6], a[7]);
                got = op == 4 ? U.P_InterceptVector(d1, d2) : P_Sight.P_InterceptVector2(d1, d2);
            } else if (op == 7) {
                c.map.sectors[0].floorheight = a[0];
                c.map.sectors[0].ceilingheight = a[1];
                c.map.sectors[1].floorheight = a[2];
                c.map.sectors[1].ceilingheight = a[3];
                c.map.lines[0].frontsector = 0;
                c.map.lines[0].backsector = 1;
                c.map.lines[0].sidenum[1] = a[4] == 0 ? C.NULL : 0;
                c.move.opentop = 11;
                c.move.openbottom = 22;
                c.move.openrange = 33;
                c.move.lowfloor = 44;
                U.P_LineOpening(c, 0);
                require(
                    c.move.opentop == e[0] && c.move.openbottom == e[1] && c.move.openrange == e[2]
                        && c.move.lowfloor == e[3],
                    "original opening and stale globals"
                );
                continue;
            } else {
                revert("unknown native operation");
            }
            require(got == e[0], "original numeric collision mismatch");
        }
        require(p == data.length, "fixture consumed");
    }

    function undefinedAbs(int32 n) external pure returns (int32) {
        return U.abs(n);
    }

    function testUndefinedAbsIntMinRejected() public {
        try this.undefinedAbs(type(int32).min) returns (int32) {
            revert("undefined C accepted");
        } catch (bytes memory reason) {
            require(bytes4(reason) == U.UndefinedMapArithmetic.selector, "domain error");
        }
    }
}
