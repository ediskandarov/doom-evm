// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @custom:source linuxdoom-1.10/am_map.c globals and r_defs.h projections
struct AMPoint {
    int32 x;
    int32 y;
}

struct AMLine {
    AMPoint a;
    AMPoint b;
}

struct AMWall {
    AMLine line;
    uint32 flags;
    int32 special;
    bool back;
    int32 frontFloor;
    int32 backFloor;
    int32 frontCeiling;
    int32 backCeiling;
}

struct AMActor {
    int32 x;
    int32 y;
    uint32 angle;
    bool ingame;
    bool invisible;
}

/// Borrowed live geometry/powers; sector thing lists are flattened in sector/snext order.
struct AMWorld {
    AMPoint[] vertices;
    AMWall[] walls;
    AMActor[4] players;
    AMActor[] things;
    int32 blockX;
    int32 blockY;
    int32 episode;
    int32 map;
    uint32 consolePlayer;
    bool allmap;
    bool netgame;
    bool deathmatch;
    bool singledemo;
}

/// Caller owns persistence. Notifications/messages replace cross-module calls only.
struct AutomapState {
    bool active;
    bool stopped;
    bool viewactive;
    bool follow;
    bool grid;
    bool big;
    uint32 cheating;
    uint32 cheatPos;
    uint32 player;
    int32 lastEpisode;
    int32 lastMap;
    int32 clock;
    int32 light;
    int32 nextLight;
    uint32 lightIndex;
    int32 panX;
    int32 panY;
    int32 zoomM;
    int32 zoomF;
    int32 x;
    int32 y;
    int32 x2;
    int32 y2;
    int32 w;
    int32 h;
    int32 minX;
    int32 minY;
    int32 maxX;
    int32 maxY;
    int32 minScale;
    int32 maxScale;
    int32 scale;
    int32 inverse;
    int32 oldX;
    int32 oldY;
    int32 oldW;
    int32 oldH;
    AMPoint oldFollow;
    AMPoint[10] marks;
    uint32 mark;
    string message;
    int32[3] notification; // original event type, data1, data2 (including AM_Stop initializer quirk)
    uint32 loads;
    uint32 unloads;
}
