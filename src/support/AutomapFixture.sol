// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {AM_Map as AM} from "../doom/am_map.sol";
import {AutomapState, AMWorld, AMPoint, AMLine, AMWall, AMActor} from "../doom/am_map_types.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {M_BBox} from "../doom/m_bbox.sol";

/// Automap-only fixture decoder. Inputs carry geometry/actions, never host-generated pixels.
library AutomapFixture {
    struct Cursor {
        uint256 pos;
    }

    function word(bytes memory input, Cursor memory cursor) internal pure returns (uint32 n) {
        require(cursor.pos + 4 <= input.length, "fixture bounds");
        uint256 p = cursor.pos;
        assembly ("memory-safe") { n := shr(224, mload(add(add(input, 32), p))) }
        cursor.pos += 4;
    }

    function signed(bytes memory input, Cursor memory c) private pure returns (int32) {
        return int32(word(input, c));
    }

    function decode(bytes memory input, Cursor memory c) internal pure returns (AMWorld memory w) {
        w.episode = signed(input, c);
        w.map = signed(input, c);
        w.consolePlayer = word(input, c);
        w.netgame = word(input, c) != 0;
        w.deathmatch = word(input, c) != 0;
        w.singledemo = word(input, c) != 0;
        w.allmap = word(input, c) != 0;
        w.blockX = signed(input, c);
        w.blockY = signed(input, c);
        for (uint256 i; i < 4; ++i) {
            w.players[i] =
                AMActor(
                signed(input, c), signed(input, c), word(input, c), word(input, c) != 0, word(input, c) != 0
            );
        }
        w.vertices = new AMPoint[](word(input, c));
        for (uint256 i; i < w.vertices.length; ++i) {
            w.vertices[i] = AMPoint(signed(input, c), signed(input, c));
        }
        w.walls = new AMWall[](word(input, c));
        for (uint256 i; i < w.walls.length; ++i) {
            AMWall memory l;
            l.line =
                AMLine(
                AMPoint(signed(input, c), signed(input, c)), AMPoint(signed(input, c), signed(input, c))
            );
            l.flags = word(input, c);
            l.special = signed(input, c);
            l.back = word(input, c) != 0;
            l.frontFloor = signed(input, c);
            l.backFloor = signed(input, c);
            l.frontCeiling = signed(input, c);
            l.backCeiling = signed(input, c);
            w.walls[i] = l;
        }
        w.things = new AMActor[](word(input, c));
        for (uint256 i; i < w.things.length; ++i) {
            w.things[i] = AMActor(signed(input, c), signed(input, c), word(input, c), true, false);
        }
    }

    function action(
        bytes memory input,
        Cursor memory c,
        AutomapState memory s,
        AMWorld memory w,
        VideoState memory v,
        bytes[10] memory nums
    ) internal pure returns (bool rc) {
        uint32 op = word(input, c);
        int32 a = signed(input, c);
        int32 b = signed(input, c);
        int32 d1 = signed(input, c);
        int32 d2 = signed(input, c);
        if (op == 0) {
            rc = AM.AM_Responder(s, w, a, b);
        } else if (op == 1) {
            for (int32 i; i < a; ++i) {
                AM.AM_Ticker(s, w);
            }
        } else if (op == 2) {
            AM.AM_Drawer(s, w, v, nums);
        } else if (op == 3) {
            w.players[uint32(a)].x = b;
            w.players[uint32(a)].y = d1;
            w.players[uint32(a)].angle = uint32(d2);
        } else if (op == 4) {
            AM.AM_Stop(s);
        } else if (op == 5) {
            w.episode = a;
            w.map = b;
            AM.AM_Start(s, w);
        } else if (op == 6) {
            w.allmap = a != 0;
        } else if (op == 7) {
            w.walls[uint32(a)].flags = uint32(b);
        } else if (op == 8) {
            w.netgame = a != 0;
            w.deathmatch = b != 0;
            w.singledemo = d1 != 0;
        } else if (op == 9) {
            s.marks[uint32(a)] = AMPoint(b, d1);
        } else if (op == 10) {
            AM.AM_updateLightLev(s);
        } else if (op == 11) {
            (int32 slope, int32 inverse) = AM.AM_getIslope(AMLine(AMPoint(a, b), AMPoint(d1, d2)));
            s.notification = [slope, inverse, int32(0)];
        } else {
            revert("fixture opcode");
        }
    }

    function flag(bool b) private pure returns (int32) {
        return b ? int32(1) : int32(0);
    }

    function snapshot(AutomapState memory s, VideoState memory v, bool rc)
        internal
        pure
        returns (bytes memory data)
    {
        int32[66] memory words;
        words[0] = flag(s.active);
        words[1] = flag(s.stopped);
        words[2] = flag(s.viewactive);
        words[3] = flag(s.follow);
        words[4] = flag(s.grid);
        words[5] = flag(s.big);
        words[6] = int32(s.cheating);
        words[7] = int32(s.cheatPos);
        words[8] = int32(s.player);
        words[9] = s.clock;
        words[10] = s.light;
        words[11] = s.panX;
        words[12] = s.panY;
        words[13] = s.zoomM;
        words[14] = s.zoomF;
        words[15] = s.x;
        words[16] = s.y;
        words[17] = s.x2;
        words[18] = s.y2;
        words[19] = s.w;
        words[20] = s.h;
        words[21] = s.minX;
        words[22] = s.minY;
        words[23] = s.maxX;
        words[24] = s.maxY;
        words[25] = s.minScale;
        words[26] = s.maxScale;
        words[27] = s.scale;
        words[28] = s.inverse;
        words[29] = s.oldX;
        words[30] = s.oldY;
        words[31] = s.oldW;
        words[32] = s.oldH;
        words[33] = s.oldFollow.x;
        words[34] = s.oldFollow.y;
        words[35] = int32(s.mark);
        for (uint256 i; i < 10; ++i) {
            words[36 + i * 2] = s.marks[i].x;
            words[37 + i * 2] = s.marks[i].y;
        }
        for (uint256 i; i < 3; ++i) {
            words[56 + i] = s.notification[i];
        }
        words[59] = int32(s.loads);
        words[60] = int32(s.unloads);
        words[61] = flag(rc);
        for (uint256 i; i < 4; ++i) {
            words[62 + i] = v.dirtybox[i];
        }
        bytes memory message = bytes(s.message);
        data = new bytes(268 + message.length);
        for (uint256 i; i < 66; ++i) {
            put(data, i * 4, uint32(words[i]));
        }
        put(data, 264, uint32(message.length));
        for (uint256 i; i < message.length; ++i) {
            data[268 + i] = message[i];
        }
    }

    function put(bytes memory data, uint256 p, uint32 n) private pure {
        data[p] = bytes1(uint8(n >> 24));
        data[p + 1] = bytes1(uint8(n >> 16));
        data[p + 2] = bytes1(uint8(n >> 8));
        data[p + 3] = bytes1(uint8(n));
    }

    function fresh() internal pure returns (VideoState memory v) {
        v.screens[0] = new bytes(64000);
        M_BBox.M_ClearBox(v.dirtybox);
        for (uint256 i; i < 64000; ++i) {
            v.screens[0][i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
        }
    }

    function replay(bytes memory input, bytes[10] memory nums)
        internal
        pure
        returns (bytes memory stateHashes, bytes memory frameHashes, bytes memory pixels)
    {
        Cursor memory c;
        AMWorld memory w = decode(input, c);
        AutomapState memory s;
        AM.AM_Init(s);
        VideoState memory v = fresh();
        uint32 count = word(input, c);
        stateHashes = new bytes(count * 32);
        frameHashes = new bytes(count * 32);
        for (uint256 i; i < count; ++i) {
            bool rc = action(input, c, s, w, v, nums);
            bytes32 sh = sha256(snapshot(s, v, rc));
            bytes32 fh = sha256(v.screens[0]);
            assembly ("memory-safe") {
                mstore(add(add(stateHashes, 32), mul(i, 32)), sh)
                mstore(add(add(frameHashes, 32), mul(i, 32)), fh)
            }
        }
        require(c.pos == input.length, "trailing fixture data");
        pixels = v.screens[0];
    }
}
