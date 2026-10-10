// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;
import {AutomapState, AMWorld, AMPoint, AMLine, AMWall, AMActor} from "./am_map_types.sol";
import {M_Fixed as F} from "./m_fixed.sol";
import {Tables} from "./tables.sol";
import {VideoState} from "./v_video_types.sol";
import {V_Video as V} from "./v_video.sol";

/// @custom:source linuxdoom-1.10/am_map.c, am_map.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
/// @notice Original north-up 320x168 automap. All clipping, rasterization and glyph rotation run in EVM.
library AM_Map {
    int32 private constant U = 65536;
    int32 private constant MAX = 2147483647;
    int32 private constant R = (8 * 16 * U) / 7;
    error AutomapInput();
    error AutomapBuffer();

    function AM_Init(AutomapState memory s) internal pure {
        s.stopped = true;
        s.viewactive = true;
        s.follow = true;
        s.scale = 13107;
        s.lastEpisode = -1;
        s.lastMap = -1;
    }

    function ftom(AutomapState memory s, int32 n) internal pure returns (int32) {
        return F.FixedMul(n << 16, s.inverse);
    }

    function mtof(AutomapState memory s, int32 n) internal pure returns (int32) {
        return F.FixedMul(n, s.scale) >> 16;
    }

    function edges(AutomapState memory s) private pure {
        unchecked {
            s.x2 = s.x + s.w;
            s.y2 = s.y + s.h;
        }
    }

    function AM_activateNewScale(AutomapState memory s) internal pure {
        unchecked {
            s.x += s.w / 2;
            s.y += s.h / 2;
            s.w = ftom(s, 320);
            s.h = ftom(s, 168);
            s.x -= s.w / 2;
            s.y -= s.h / 2;
        }
        edges(s);
    }

    function AM_saveScaleAndLoc(AutomapState memory s) internal pure {
        s.oldX = s.x;
        s.oldY = s.y;
        s.oldW = s.w;
        s.oldH = s.h;
    }

    function AM_restoreScaleAndLoc(AutomapState memory s, AMWorld memory world) internal pure {
        s.w = s.oldW;
        s.h = s.oldH;
        unchecked {
            s.x = s.follow ? world.players[s.player].x - s.w / 2 : s.oldX;
            s.y = s.follow ? world.players[s.player].y - s.h / 2 : s.oldY;
        }
        edges(s);
        s.scale = F.FixedDiv(320 << 16, s.w);
        s.inverse = F.FixedDiv(U, s.scale);
    }

    function AM_clearMarks(AutomapState memory s) internal pure {
        for (uint256 i; i < 10; ++i) {
            s.marks[i].x = -1;
        }
        s.mark = 0;
    }

    function AM_addMark(AutomapState memory s) internal pure {
        unchecked {
            s.marks[s.mark] = AMPoint(s.x + s.w / 2, s.y + s.h / 2);
        }
        s.mark = (s.mark + 1) % 10;
    }

    function AM_findMinMaxBoundaries(AutomapState memory s, AMPoint[] memory vertices) internal pure {
        if (vertices.length == 0) revert AutomapInput();
        s.minX = MAX;
        s.minY = MAX;
        s.maxX = -MAX;
        s.maxY = -MAX;
        // Preserve the original else-if (including its vertex-order behavior).
        for (uint256 i; i < vertices.length; ++i) {
            AMPoint memory p = vertices[i];
            if (p.x < s.minX) s.minX = p.x;
            else if (p.x > s.maxX) s.maxX = p.x;
            if (p.y < s.minY) s.minY = p.y;
            else if (p.y > s.maxY) s.maxY = p.y;
        }
        unchecked {
            int32 a = F.FixedDiv(320 << 16, s.maxX - s.minX);
            int32 b = F.FixedDiv(168 << 16, s.maxY - s.minY);
            s.minScale = a < b ? a : b;
        }
        s.maxScale = F.FixedDiv(168 << 16, 32 * U);
    }

    function AM_LevelInit(AutomapState memory s, AMWorld memory world) internal pure {
        AM_clearMarks(s);
        AM_findMinMaxBoundaries(s, world.vertices);
        s.scale = F.FixedDiv(s.minScale, 45875);
        if (s.scale > s.maxScale) s.scale = s.minScale;
        s.inverse = F.FixedDiv(U, s.scale);
    }

    function AM_changeWindowLoc(AutomapState memory s) internal pure {
        unchecked {
            if (s.panX != 0 || s.panY != 0) {
                s.follow = false;
                s.oldFollow.x = MAX;
            }
            s.x += s.panX;
            s.y += s.panY;
            if (s.x + s.w / 2 > s.maxX) s.x = s.maxX - s.w / 2;
            else if (s.x + s.w / 2 < s.minX) s.x = s.minX - s.w / 2;
            if (s.y + s.h / 2 > s.maxY) s.y = s.maxY - s.h / 2;
            else if (s.y + s.h / 2 < s.minY) s.y = s.minY - s.h / 2;
        }
        edges(s);
    }

    function AM_initVariables(AutomapState memory s, AMWorld memory world) internal pure {
        s.active = true;
        s.oldFollow.x = MAX;
        s.clock = 0;
        s.light = 0;
        s.panX = 0;
        s.panY = 0;
        s.zoomM = U;
        s.zoomF = U;
        s.w = ftom(s, 320);
        s.h = ftom(s, 168);
        uint32 p = world.consolePlayer;
        if (p >= 4) revert AutomapInput();
        if (!world.players[p].ingame) for (p = 0; p < 4; ++p) {
            if (world.players[p].ingame) break;
        }
        if (p == 4) revert AutomapInput();
        s.player = p;
        unchecked {
            s.x = world.players[p].x - s.w / 2;
            s.y = world.players[p].y - s.h / 2;
        }
        AM_changeWindowLoc(s);
        AM_saveScaleAndLoc(s);
        s.notification = [int32(1), int32(0x616d6500), int32(0)];
    }

    function AM_loadPics(AutomapState memory s) internal pure {
        ++s.loads;
    }

    function AM_unloadPics(AutomapState memory s) internal pure {
        ++s.unloads;
    }

    function AM_Stop(AutomapState memory s) internal pure {
        AM_unloadPics(s);
        s.active = false;
        s.stopped = true;
        // Original {0, ev_keyup, AM_MSGEXITED} differs from the entered event initializer.
        s.notification = [int32(0), int32(1), int32(0x616d7800)];
    }

    function AM_Start(AutomapState memory s, AMWorld memory world) internal pure {
        if (!s.stopped) AM_Stop(s);
        s.stopped = false;
        if (s.lastMap != world.map || s.lastEpisode != world.episode) {
            AM_LevelInit(s, world);
            s.lastMap = world.map;
            s.lastEpisode = world.episode;
        }
        AM_initVariables(s, world);
        AM_loadPics(s);
    }

    function AM_minOutWindowScale(AutomapState memory s) internal pure {
        s.scale = s.minScale;
        s.inverse = F.FixedDiv(U, s.scale);
        AM_activateNewScale(s);
    }

    function AM_maxOutWindowScale(AutomapState memory s) internal pure {
        s.scale = s.maxScale;
        s.inverse = F.FixedDiv(U, s.scale);
        AM_activateNewScale(s);
    }

    function AM_Responder(AutomapState memory s, AMWorld memory world, int32 eventType, int32 key)
        internal
        pure
        returns (bool rc)
    {
        if (!s.active) {
            if (eventType == 0 && key == 9) {
                AM_Start(s, world);
                s.viewactive = false;
                return true;
            }
        } else if (eventType == 0) {
            rc = true;
            if (key == 0xae || key == 0xac) {
                if (!s.follow) s.panX = key == 0xae ? ftom(s, 4) : -ftom(s, 4);
                else rc = false;
            } else if (key == 0xad || key == 0xaf) {
                if (!s.follow) s.panY = key == 0xad ? ftom(s, 4) : -ftom(s, 4);
                else rc = false;
            } else if (key == 45) {
                s.zoomM = 64250;
                s.zoomF = 66846;
            } else if (key == 61) {
                s.zoomM = 66846;
                s.zoomF = 64250;
            } else if (key == 9) {
                s.big = false;
                s.viewactive = true;
                AM_Stop(s);
            } else if (key == 48) {
                s.big = !s.big;
                if (s.big) {
                    AM_saveScaleAndLoc(s);
                    AM_minOutWindowScale(s);
                } else {
                    AM_restoreScaleAndLoc(s, world);
                }
            } else if (key == 102) {
                s.follow = !s.follow;
                s.oldFollow.x = MAX;
                s.message = s.follow ? "Follow Mode ON" : "Follow Mode OFF";
            } else if (key == 103) {
                s.grid = !s.grid;
                s.message = s.grid ? "Grid ON" : "Grid OFF";
            } else if (key == 109) {
                s.message = string(abi.encodePacked("Marked Spot ", bytes1(uint8(48 + s.mark))));
                AM_addMark(s);
            } else if (key == 99) {
                AM_clearMarks(s);
                s.message = "All Marks Cleared";
            } else {
                rc = false;
            }
            // m_cheat.c matcher resets on mismatch without reconsidering the current key.
            if (!world.deathmatch) {
                bytes memory seq = bytes("iddt");
                if (uint8(uint32(key)) == uint8(seq[s.cheatPos])) ++s.cheatPos;
                else s.cheatPos = 0;
                if (s.cheatPos == 4) {
                    s.cheatPos = 0;
                    s.cheating = (s.cheating + 1) % 3;
                    rc = false;
                }
            }
        } else if (eventType == 1) {
            if (!s.follow && (key == 0xae || key == 0xac)) s.panX = 0;
            else if (!s.follow && (key == 0xad || key == 0xaf)) s.panY = 0;
            if (key == 45 || key == 61) {
                s.zoomM = U;
                s.zoomF = U;
            }
        }
    }

    function AM_changeWindowScale(AutomapState memory s) internal pure {
        s.scale = F.FixedMul(s.scale, s.zoomM);
        s.inverse = F.FixedDiv(U, s.scale);
        if (s.scale < s.minScale) AM_minOutWindowScale(s);
        else if (s.scale > s.maxScale) AM_maxOutWindowScale(s);
        else AM_activateNewScale(s);
    }

    function AM_doFollowPlayer(AutomapState memory s, AMActor memory p) internal pure {
        if (s.oldFollow.x != p.x || s.oldFollow.y != p.y) {
            unchecked {
                s.x = ftom(s, mtof(s, p.x)) - s.w / 2;
                s.y = ftom(s, mtof(s, p.y)) - s.h / 2;
            }
            edges(s);
            s.oldFollow = AMPoint(p.x, p.y);
        }
    }

    function AM_updateLightLev(AutomapState memory s) internal pure {
        if (s.clock > s.nextLight) {
            int32[8] memory levels = [int32(0), 4, 7, 10, 12, 14, 15, 15];
            s.light = levels[s.lightIndex];
            s.lightIndex = (s.lightIndex + 1) % 8;
            unchecked {
                s.nextLight = s.clock + 6 - (s.clock % 6);
            }
        }
    }

    function AM_Ticker(AutomapState memory s, AMWorld memory world) internal pure {
        if (!s.active) return;
        unchecked {
            ++s.clock;
        }
        if (s.follow) AM_doFollowPlayer(s, world.players[s.player]);
        if (s.zoomF != U) AM_changeWindowScale(s);
        if (s.panX != 0 || s.panY != 0) AM_changeWindowLoc(s);
        // Original AM_updateLightLev call is disabled.
    }

    function AM_getIslope(AMLine memory l) internal pure returns (int32 slope, int32 inverseSlope) {
        unchecked {
            int32 dy = l.a.y - l.b.y;
            int32 dx = l.b.x - l.a.x;
            inverseSlope = dy == 0 ? (dx < 0 ? -MAX : MAX) : F.FixedDiv(dx, dy);
            slope = dx == 0 ? (dy < 0 ? -MAX : MAX) : F.FixedDiv(dy, dx);
        }
    }

    function outcode(AMPoint memory p) private pure returns (uint32 oc) {
        if (p.y < 0) oc = 8;
        else if (p.y >= 168) oc = 4;
        if (p.x < 0) oc |= 1;
        else if (p.x >= 320) oc |= 2;
    }

    function AM_clipMline(AutomapState memory s, AMLine memory l)
        internal
        pure
        returns (bool, AMLine memory fl)
    {
        unchecked {
            uint32 a;
            uint32 b;
            if (l.a.y > s.y2) a = 8;
            else if (l.a.y < s.y) a = 4;
            if (l.b.y > s.y2) b = 8;
            else if (l.b.y < s.y) b = 4;
            if ((a & b) != 0) return (false, fl);
            if (l.a.x < s.x) a |= 1;
            else if (l.a.x > s.x2) a |= 2;
            if (l.b.x < s.x) b |= 1;
            else if (l.b.x > s.x2) b |= 2;
            if ((a & b) != 0) return (false, fl);
            fl.a = AMPoint(mtof(s, l.a.x - s.x), 168 - mtof(s, l.a.y - s.y));
            fl.b = AMPoint(mtof(s, l.b.x - s.x), 168 - mtof(s, l.b.y - s.y));
            a = outcode(fl.a);
            b = outcode(fl.b);
            if ((a & b) != 0) return (false, fl);
            while ((a | b) != 0) {
                uint32 outside = a != 0 ? a : b;
                AMPoint memory p;
                int32 dx;
                int32 dy;
                if ((outside & 8) != 0) {
                    dy = fl.a.y - fl.b.y;
                    dx = fl.b.x - fl.a.x;
                    p.x = fl.a.x + (dx * fl.a.y) / dy;
                    p.y = 0;
                } else if ((outside & 4) != 0) {
                    dy = fl.a.y - fl.b.y;
                    dx = fl.b.x - fl.a.x;
                    p.x = fl.a.x + (dx * (fl.a.y - 168)) / dy;
                    p.y = 167;
                } else if ((outside & 2) != 0) {
                    dy = fl.b.y - fl.a.y;
                    dx = fl.b.x - fl.a.x;
                    p.y = fl.a.y + (dy * (319 - fl.a.x)) / dx;
                    p.x = 319;
                } else {
                    dy = fl.b.y - fl.a.y;
                    dx = fl.b.x - fl.a.x;
                    p.y = fl.a.y + (dy * (-fl.a.x)) / dx;
                    p.x = 0;
                }
                if (outside == a) {
                    fl.a = p;
                    a = outcode(fl.a);
                } else {
                    fl.b = p;
                    b = outcode(fl.b);
                }
                if ((a & b) != 0) return (false, fl);
            }
            return (true, fl);
        }
    }

    function AM_drawFline(bytes memory fb, AMLine memory l, uint8 color) internal pure {
        if (outcode(l.a) != 0 || outcode(l.b) != 0) return; // original debug early return
        if (fb.length < 320 * 168) revert AutomapBuffer();
        unchecked {
            int32 dx = l.b.x - l.a.x;
            int32 dy = l.b.y - l.a.y;
            int32 ax = 2 * (dx < 0 ? -dx : dx);
            int32 ay = 2 * (dy < 0 ? -dy : dy);
            int32 sx = dx < 0 ? int32(-1) : int32(1);
            int32 sy = dy < 0 ? int32(-1) : int32(1);
            int32 x = l.a.x;
            int32 y = l.a.y;
            int32 d = ax > ay ? ay - ax / 2 : ax - ay / 2;
            while (true) {
                fb[uint32(y) * 320 + uint32(x)] = bytes1(color);
                if (ax > ay) {
                    if (x == l.b.x) return;
                    if (d >= 0) {
                        y += sy;
                        d -= ax;
                    }
                    x += sx;
                    d += ay;
                } else {
                    if (y == l.b.y) return;
                    if (d >= 0) {
                        x += sx;
                        d -= ay;
                    }
                    y += sy;
                    d += ax;
                }
            }
        }
    }

    function AM_drawMline(AutomapState memory s, bytes memory fb, AMLine memory l, uint8 color)
        internal
        pure
    {
        (bool visible, AMLine memory fl) = AM_clipMline(s, l);
        if (visible) AM_drawFline(fb, fl, color);
    }

    function AM_drawGrid(AutomapState memory s, AMWorld memory world, bytes memory fb, uint8 color)
        internal
        pure
    {
        unchecked {
            int32 blockSize = 128 << 16;
            int32 start = s.x;
            if ((start - world.blockX) % blockSize != 0) start += blockSize - ((start - world.blockX) % blockSize);
            for (int32 x = start; x < s.x + s.w; x += blockSize) {
                AM_drawMline(s, fb, AMLine(AMPoint(x, s.y), AMPoint(x, s.y + s.h)), color);
            }
            start = s.y;
            if ((start - world.blockY) % blockSize != 0) start += blockSize - ((start - world.blockY) % blockSize);
            for (int32 y = start; y < s.y + s.h; y += blockSize) {
                AM_drawMline(s, fb, AMLine(AMPoint(s.x, y), AMPoint(s.x + s.w, y)), color);
            }
        }
    }

    function AM_drawWalls(AutomapState memory s, AMWorld memory world, bytes memory fb) internal pure {
        for (uint256 i; i < world.walls.length; ++i) {
            AMWall memory wall = world.walls[i];
            uint8 color;
            if (s.cheating != 0 || (wall.flags & 256) != 0) {
                if ((wall.flags & 128) != 0 && s.cheating == 0) continue;
                if (!wall.back) color = 176;
                else if (wall.special == 39) {
                    AM_drawMline(s, fb, wall.line, 184);
                    continue;
                } else if ((wall.flags & 32) != 0) color = 176;
                else if (wall.backFloor != wall.frontFloor) color = 64;
                else if (wall.backCeiling != wall.frontCeiling) color = 231;
                else if (s.cheating != 0) color = 96;
                else continue;
                unchecked {
                    color += uint8(uint32(s.light));
                }
            } else if (world.allmap && (wall.flags & 128) == 0) {
                color = 99;
            } else {
                continue;
            }
            AM_drawMline(s, fb, wall.line, color);
        }
    }

    function AM_rotate(AMPoint memory p, uint32 angle) internal pure {
        int32 c = Tables.finecosine(angle >> 19);
        int32 sn = Tables.finesine(angle >> 19);
        unchecked {
            int32 x = F.FixedMul(p.x, c) - F.FixedMul(p.y, sn);
            p.y = F.FixedMul(p.x, sn) + F.FixedMul(p.y, c);
            p.x = x;
        }
    }

    function AM_drawLineCharacter(
        AutomapState memory s,
        bytes memory fb,
        AMLine[] memory glyph,
        int32 scale,
        uint32 angle,
        uint8 color,
        int32 x,
        int32 y
    ) internal pure {
        for (uint256 i; i < glyph.length; ++i) {
            // Deep copy: drawing must not mutate the caller's vector glyph.
            AMLine memory l = AMLine(AMPoint(glyph[i].a.x, glyph[i].a.y), AMPoint(glyph[i].b.x, glyph[i].b.y));
            if (scale != 0) {
                l.a.x = F.FixedMul(scale, l.a.x);
                l.a.y = F.FixedMul(scale, l.a.y);
                l.b.x = F.FixedMul(scale, l.b.x);
                l.b.y = F.FixedMul(scale, l.b.y);
            }
            if (angle != 0) {
                AM_rotate(l.a, angle);
                AM_rotate(l.b, angle);
            }
            unchecked {
                l.a.x += x;
                l.a.y += y;
                l.b.x += x;
                l.b.y += y;
            }
            AM_drawMline(s, fb, l, color);
        }
    }

    function line(int32 ax, int32 ay, int32 bx, int32 by) private pure returns (AMLine memory) {
        return AMLine(AMPoint(ax, ay), AMPoint(bx, by));
    }

    function playerArrow(bool cheat) internal pure returns (AMLine[] memory g) {
        g = new AMLine[](cheat ? 16 : 7);
        int32 tip = cheat ? R / 6 : R / 4;
        g[0] = line(-R + R / 8, 0, R, 0);
        g[1] = line(R, 0, R - R / 2, tip);
        g[2] = line(R, 0, R - R / 2, -tip);
        g[3] = line(-R + R / 8, 0, -R - R / 8, tip);
        g[4] = line(-R + R / 8, 0, -R - R / 8, -tip);
        g[5] = line(-R + 3 * R / 8, 0, -R + R / 8, tip);
        g[6] = line(-R + 3 * R / 8, 0, -R + R / 8, -tip);
        if (cheat) {
            g[7] = line(-R / 2, 0, -R / 2, -R / 6);
            g[8] = line(-R / 2, -R / 6, -R / 2 + R / 6, -R / 6);
            g[9] = line(-R / 2 + R / 6, -R / 6, -R / 2 + R / 6, R / 4);
            g[10] = line(-R / 6, 0, -R / 6, -R / 6);
            g[11] = line(-R / 6, -R / 6, 0, -R / 6);
            g[12] = line(0, -R / 6, 0, R / 4);
            g[13] = line(R / 6, R / 4, R / 6, -R / 7);
            g[14] = line(R / 6, -R / 7, R / 6 + R / 32, -R / 7 - R / 32);
            g[15] = line(R / 6 + R / 32, -R / 7 - R / 32, R / 6 + R / 10, -R / 7);
        }
    }

    function AM_drawPlayers(AutomapState memory s, AMWorld memory world, bytes memory fb) internal pure {
        if (!world.netgame) {
            AMActor memory p = world.players[s.player];
            AM_drawLineCharacter(s, fb, playerArrow(s.cheating != 0), 0, p.angle, 209, p.x, p.y);
            return;
        }
        uint8[4] memory colors = [uint8(112), 96, 64, 176];
        AMLine[] memory arrow = playerArrow(false);
        for (uint256 i; i < 4; ++i) {
            if (world.deathmatch && !world.singledemo && i != s.player) continue;
            AMActor memory p = world.players[i];
            if (!p.ingame) continue;
            AM_drawLineCharacter(s, fb, arrow, 0, p.angle, p.invisible ? 246 : colors[i], p.x, p.y);
        }
    }

    function AM_drawThings(AutomapState memory s, AMWorld memory world, bytes memory fb, uint8 color)
        internal
        pure
    {
        AMLine[] memory g = new AMLine[](3);
        g[0] = line(-32768, -45875, 65536, 0);
        g[1] = line(65536, 0, -32768, 45875);
        g[2] = line(-32768, 45875, -32768, -45875);
        for (uint256 i; i < world.things.length; ++i) {
            AMActor memory p = world.things[i];
            AM_drawLineCharacter(s, fb, g, 16 << 16, p.angle, color, p.x, p.y);
        }
    }

    function AM_drawMarks(AutomapState memory s, VideoState memory v, bytes[10] memory nums) internal pure {
        for (uint256 i; i < 10; ++i) {
            if (s.marks[i].x != -1) {
                int32 fx;
                int32 fy;
                unchecked {
                    fx = mtof(s, s.marks[i].x - s.x);
                    fy = 168 - mtof(s, s.marks[i].y - s.y);
                }
                if (fx >= 0 && fx <= 315 && fy >= 0 && fy <= 162) V.V_DrawPatch(v, fx, fy, 0, nums[i]);
            }
        }
    }

    function AM_clearFB(bytes memory fb, uint8 color) internal pure {
        if (fb.length < 53760) revert AutomapBuffer();
        // Whole words, exact owned range; 53760 is word aligned. Preserve bottom 32 rows.
        assembly ("memory-safe") {
            let word := mul(color, 0x0101010101010101010101010101010101010101010101010101010101010101)
            let end := add(add(fb, 32), 53760)
            for { let p := add(fb, 32) } lt(p, end) { p := add(p, 32) } { mstore(p, word) }
        }
    }

    function AM_drawCrosshair(bytes memory fb, uint8 color) internal pure {
        fb[(320 * 169) / 2] = bytes1(color);
    }

    function AM_Drawer(
        AutomapState memory s,
        AMWorld memory world,
        VideoState memory v,
        bytes[10] memory nums
    ) internal pure {
        if (!s.active) return;
        bytes memory fb = v.screens[0];
        AM_clearFB(fb, 0);
        if (s.grid) AM_drawGrid(s, world, fb, 104);
        AM_drawWalls(s, world, fb);
        AM_drawPlayers(s, world, fb);
        if (s.cheating == 2) {
            unchecked {
                AM_drawThings(s, world, fb, uint8(uint32(112 + s.light)));
            }
        }
        AM_drawCrosshair(fb, 96);
        AM_drawMarks(s, v, nums);
        V.V_MarkRect(v, 0, 0, 320, 168);
    }
}
