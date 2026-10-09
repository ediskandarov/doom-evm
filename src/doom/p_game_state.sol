// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
pragma solidity 0.8.37;

import {MapData, MapThing} from "./r_defs.sol";
import {RenderResources} from "./r_data_types.sol";
import {Ticcmd, GameInputState} from "./d_ticcmd.sol";
import {WallState, PlaneState} from "./r_render_state.sol";
import {ZoneState} from "./z_zone_types.sol";

/// @custom:source linuxdoom-1.10/{doomdef,p_local,p_mobj,p_pspr}.h at a77dfb96cb91780ca334d0d4cfd86957558007e0
library GameConst {
    uint32 internal constant NULL = type(uint32).max;
    uint32 internal constant THINKER_CAP = 0;
    int32 internal constant FRACUNIT = 65536;
    int32 internal constant TICRATE = 35;
    int32 internal constant VIEWHEIGHT = 41 * FRACUNIT;
    int32 internal constant PLAYERRADIUS = 16 * FRACUNIT;
    int32 internal constant MAXRADIUS = 32 * FRACUNIT;
    int32 internal constant GRAVITY = FRACUNIT;
    int32 internal constant MAXMOVE = 30 * FRACUNIT;
    int32 internal constant USERANGE = 64 * FRACUNIT;
    int32 internal constant MELEERANGE = 64 * FRACUNIT;
    int32 internal constant MISSILERANGE = 32 * 64 * FRACUNIT;
    int32 internal constant BASETHRESHOLD = 100;
    int32 internal constant FLOATSPEED = 4 * FRACUNIT;
    int32 internal constant ONFLOORZ = type(int32).min;
    int32 internal constant ONCEILINGZ = type(int32).max;
    uint32 internal constant MF_SPECIAL = 1;
    uint32 internal constant MF_SOLID = 2;
    uint32 internal constant MF_SHOOTABLE = 4;
    uint32 internal constant MF_NOSECTOR = 8;
    uint32 internal constant MF_NOBLOCKMAP = 16;
    uint32 internal constant MF_AMBUSH = 32;
    uint32 internal constant MF_JUSTHIT = 64;
    uint32 internal constant MF_JUSTATTACKED = 128;
    uint32 internal constant MF_SPAWNCEILING = 256;
    uint32 internal constant MF_NOGRAVITY = 512;
    uint32 internal constant MF_DROPOFF = 0x400;
    uint32 internal constant MF_PICKUP = 0x800;
    uint32 internal constant MF_NOCLIP = 0x1000;
    uint32 internal constant MF_SLIDE = 0x2000;
    uint32 internal constant MF_FLOAT = 0x4000;
    uint32 internal constant MF_TELEPORT = 0x8000;
    uint32 internal constant MF_MISSILE = 0x10000;
    uint32 internal constant MF_DROPPED = 0x20000;
    uint32 internal constant MF_SHADOW = 0x40000;
    uint32 internal constant MF_NOBLOOD = 0x80000;
    uint32 internal constant MF_CORPSE = 0x100000;
    uint32 internal constant MF_INFLOAT = 0x200000;
    uint32 internal constant MF_COUNTKILL = 0x400000;
    uint32 internal constant MF_COUNTITEM = 0x800000;
    uint32 internal constant MF_SKULLFLY = 0x1000000;
    uint32 internal constant MF_NOTDMATCH = 0x2000000;
    uint32 internal constant MF_TRANSLATION = 0xc000000;
    uint32 internal constant MF_TRANSSHIFT = 26;
    uint32 internal constant FF_FULLBRIGHT = 0x8000;
    uint32 internal constant FF_FRAMEMASK = 0x7fff;
    int32 internal constant CF_NOCLIP = 1;
    int32 internal constant CF_GODMODE = 2;
    int32 internal constant CF_NOMOMENTUM = 4;
    uint8 internal constant BT_ATTACK = 1;
    uint8 internal constant BT_USE = 2;
    uint8 internal constant BT_CHANGE = 4;
    uint8 internal constant BT_WEAPONMASK = 8 + 16 + 32;
    uint8 internal constant BT_WEAPONSHIFT = 3;
    uint8 internal constant BT_SPECIAL = 128;
    uint8 internal constant THINKER_ACTIVE = 0;
    uint8 internal constant THINKER_STASIS = 1;
    uint8 internal constant THINKER_REMOVE = 2;
}

enum PlayerState {
    live,
    dead,
    reborn
}
enum ThinkerKind {
    cap,
    mobj,
    door,
    floor,
    ceiling,
    plat,
    fireFlicker,
    lightFlash,
    strobe,
    glow
}
enum DoorType {
    normal,
    close30ThenOpen,
    close,
    open,
    raiseIn5Mins,
    blazeRaise,
    blazeOpen,
    blazeClose
}
enum FloorType {
    lowerFloor,
    lowerFloorToLowest,
    turboLower,
    raiseFloor,
    raiseFloorToNearest,
    raiseToTexture,
    lowerAndChange,
    raiseFloor24,
    raiseFloor24AndChange,
    raiseFloorCrush,
    raiseFloorTurbo,
    donutRaise,
    raiseFloor512
}
enum CeilingType {
    lowerToFloor,
    raiseToHighest,
    lowerAndCrush,
    crushAndRaise,
    fastCrushAndRaise,
    silentCrushAndRaise
}
enum PlatStatus {
    up,
    down,
    waiting,
    inStasis
}
enum PlatType {
    perpetualRaise,
    downWaitUpStay,
    raiseAndChange,
    raiseToNearestAndChange,
    blazeDWUS
}
enum ButtonWhere {
    top,
    middle,
    bottom
}
enum PlaneResult {
    ok,
    crushed,
    pastdest
}

/// @custom:source info.h state_t; action IDs are generated from original action symbols, 0=NULL.
struct StateDef {
    uint32 sprite;
    uint32 frame;
    int32 tics;
    uint32 action;
    uint32 nextstate;
    int32 misc1;
    int32 misc2;
}

/// @custom:source info.h mobjinfo_t, all 23 original fields in original order.
struct MobjInfo {
    int32 doomednum;
    int32 spawnstate;
    int32 spawnhealth;
    int32 seestate;
    int32 seesound;
    int32 reactiontime;
    int32 attacksound;
    int32 painstate;
    int32 painchance;
    int32 painsound;
    int32 meleestate;
    int32 missilestate;
    int32 deathstate;
    int32 xdeathstate;
    int32 deathsound;
    int32 speed;
    int32 radius;
    int32 height;
    int32 mass;
    int32 damage;
    int32 activesound;
    int32 flags;
    int32 raisestate;
}

/// @custom:source d_items.h weaponinfo_t.
struct WeaponInfo {
    int32 ammo;
    uint32 upstate;
    uint32 downstate;
    uint32 readystate;
    uint32 atkstate;
    uint32 flashstate;
}

struct GameDefinitions {
    StateDef[] states;
    MobjInfo[] mobjinfo;
    WeaponInfo[9] weaponinfo;
}

/// @custom:source p_pspr.h pspdef_t. NULL state is GameConst.NULL, not S_NULL=0.
struct PlayerPSprite {
    uint32 state;
    int32 tics;
    int32 sx;
    int32 sy;
}

/// @custom:source d_player.h player_t. Pointer identity becomes stable actor/player IDs.
struct Player {
    uint32 mo;
    PlayerState playerstate;
    Ticcmd cmd;
    int32 viewz;
    int32 viewheight;
    int32 deltaviewheight;
    int32 bob;
    int32 health;
    int32 armorpoints;
    int32 armortype;
    int32[6] powers;
    bool[6] cards;
    bool backpack;
    int32[4] frags;
    uint32 readyweapon;
    uint32 pendingweapon;
    bool[9] weaponowned;
    int32[4] ammo;
    int32[4] maxammo;
    int32 attackdown;
    int32 usedown;
    int32 cheats;
    int32 refire;
    int32 killcount;
    int32 itemcount;
    int32 secretcount;
    string message;
    int32 damagecount;
    int32 bonuscount;
    uint32 attacker;
    int32 extralight;
    int32 fixedcolormap;
    int32 colormap;
    PlayerPSprite[2] psprites;
    bool didsecret;
}

/// @custom:source p_mobj.h mobj_t. info pointer is derived as definitions.mobjinfo[type].
struct Mobj {
    uint32 thinker;
    int32 x;
    int32 y;
    int32 z;
    uint32 snext;
    uint32 sprev;
    uint32 angle;
    uint32 sprite;
    uint32 frame;
    uint32 bnext;
    uint32 bprev;
    uint32 subsector;
    int32 floorz;
    int32 ceilingz;
    int32 radius;
    int32 height;
    int32 momx;
    int32 momy;
    int32 momz;
    uint32 validcount;
    uint32 mobjType;
    int32 tics;
    uint32 state;
    uint32 flags;
    int32 health;
    int32 movedir;
    int32 movecount;
    uint32 target;
    int32 reactiontime;
    int32 threshold;
    uint32 player;
    int32 lastlook;
    MapThing spawnpoint;
    uint32 tracer;
    bool allocated; // adapter tombstone, never compacts stable actor IDs.
}

/// @custom:source d_think.h thinker_t, p_tick.c lazy removal and null callback stasis.
struct Thinker {
    uint32 prev;
    uint32 next;
    ThinkerKind kind;
    uint32 payload;
    uint8 status;
}

/// @custom:source r_defs.h sector_t fields absent from renderer Sector.
struct GameSector {
    int16 special;
    int16 tag;
    int32 soundtraversed;
    uint32 soundtarget;
    int32[4] blockbox;
    int32 soundorgx;
    int32 soundorgy;
    int32 soundorgz;
    uint32 validcount;
    uint32 thinglist;
    uint32 specialdata; // thinker ID, NULL if no reversible sector action.
    uint32[] lines; // original P_GroupLines order; length replaces linecount.
}

/// @custom:source p_spec.h vldoor_t/floormove_t/ceiling_t/plat_t and light thinkers.
struct Door {
    uint32 thinker;
    DoorType doorType;
    uint32 sector;
    int32 topheight;
    int32 speed;
    int32 direction;
    int32 topwait;
    int32 topcountdown;
}

struct FloorMove {
    uint32 thinker;
    FloorType floorType;
    bool crush;
    uint32 sector;
    int32 direction;
    int32 newspecial;
    int16 texture;
    int32 floordestheight;
    int32 speed;
}

struct CeilingMove {
    uint32 thinker;
    CeilingType ceilingType;
    uint32 sector;
    int32 bottomheight;
    int32 topheight;
    int32 speed;
    bool crush;
    int32 direction;
    int32 tag;
    int32 olddirection;
}

struct Plat {
    uint32 thinker;
    uint32 sector;
    int32 speed;
    int32 low;
    int32 high;
    int32 wait;
    int32 count;
    PlatStatus status;
    PlatStatus oldstatus;
    bool crush;
    int32 tag;
    PlatType platType;
}

struct FireFlicker {
    uint32 thinker;
    uint32 sector;
    int32 count;
    int32 maxlight;
    int32 minlight;
}

struct LightFlash {
    uint32 thinker;
    uint32 sector;
    int32 count;
    int32 maxlight;
    int32 minlight;
    int32 maxtime;
    int32 mintime;
}

struct Strobe {
    uint32 thinker;
    uint32 sector;
    int32 count;
    int32 minlight;
    int32 maxlight;
    int32 darktime;
    int32 brighttime;
}

struct Glow {
    uint32 thinker;
    uint32 sector;
    int32 minlight;
    int32 maxlight;
    int32 direction;
}

struct Button {
    uint32 line;
    ButtonWhere where;
    int32 btexture;
    int32 btimer;
    uint32 soundsector;
}

/// @custom:source p_spec.c anim_t. Rendering translations are derived from leveltime.
struct Animation {
    bool istexture;
    int32 picnum;
    int32 basepic;
    int32 numpics;
    int32 speed;
}

/// @custom:source p_setup.c BLOCKMAP/REJECT globals; original signed words and list order retained.
struct BlockMap {
    int16[] lump;
    int32 width;
    int32 height;
    int32 orgx;
    int32 orgy;
    uint32[] heads;
}

struct GameState {
    // Original physical allocation ledger; byteLength zero keeps isolated legacy contexts disabled.
    ZoneState nativeZone;
    // Stable payload index -> native block ID, indexed by uint32(ThinkerKind) - 1.
    // The thinker itself is embedded in the original allocation, never allocated twice.
    uint32[][9] nativePayloadBlocks;
    // blocklinks, vertexes, sectors, sides, lines, subsectors, nodes, segs, grouped line buffer.
    uint32[9] nativeMapBlocks;
    MapData map; // authoritative mutable heights/light, side textures, line flags/specials.
    uint64 gametic;
    int32 leveltime;
    int32 gameskill;
    int32 gamemode;
    int32 gameepisode;
    int32 gamemap;
    uint32 skyflatnum;
    uint32 skytexture;
    int32 gamestate;
    int32 gameaction;
    bool paused;
    bool menuactive;
    bool demoplayback;
    bool netgame;
    int32 deathmatch;
    bool respawnmonsters;
    bool nomonsters;
    bool fastparm;
    int32 consoleplayer;
    int32 displayplayer;
    bool[4] playeringame;
    Player[4] players;
    GameInputState input;
    uint32 prndindex;
    uint32 rndindex;
    Mobj[] mobjs;
    uint32 mobjCount;
    Thinker[] thinkers; // index 0 is the live cap, NULL remains 0xffffffff.
    uint32 thinkerCount;
    GameSector[] sectors;
    uint32[] lineValidcount;
    uint32[] lineSpecialdata;
    uint32 validcount;
    BlockMap blockmap;
    bytes rejectmatrix;
    Door[] doors;
    uint32 doorCount;
    FloorMove[] floors;
    uint32 floorCount;
    CeilingMove[] ceilings;
    uint32 ceilingCount;
    Plat[] plats;
    uint32 platCount;
    FireFlicker[] fireFlickers;
    uint32 fireFlickerCount;
    LightFlash[] lightFlashes;
    uint32 lightFlashCount;
    Strobe[] strobes;
    uint32 strobeCount;
    Glow[] glows;
    uint32 glowCount;
    uint32[30] activeceilings;
    uint32[30] activeplats;
    Button[16] buttons;
    Animation[] animations; // original maximum 32, no silent truncation.
    uint32[] texturetranslation;
    uint32[] flattranslation;
    uint32[] scrollingLines; // original linespeciallist; original maximum 64.
    int32[] switchlist; // original paired texture IDs terminated by -1.
    int32 numswitches;
    bool levelTimer;
    int32 levelTimeCount;
    MapThing[128] itemrespawnque;
    int32[128] itemrespawntime;
    uint32 iquehead;
    uint32 iquetail;
    MapThing[4] playerstarts;
    MapThing[10] deathmatchstarts;
    uint32 deathmatchStartCount;
    int32 totalkills;
    int32 totalitems;
    int32 totalsecret;
    bool secretExit;
    uint32[] brainTargets; // p_enemy.c braintargets, original maximum 32.
    uint32 brainTargetOn;
    int32 brainEasy;
    // Original globals survive transactions, including P_User onground during reaction time.
    MapScratch move;
    PathScratch path;
    // R_ClearPlanes clears cachedheight only; the other caches must survive frames.
    WallState renderWall;
    PlaneState renderPlane;
    uint32 renderFuzzpos;
    uint32 renderFramecount;
    bytes renderFramebuffer;
}

/// @custom:source p_local.h divline_t/intercept_t; index discriminated by isaline.
struct DivLine {
    int32 x;
    int32 y;
    int32 dx;
    int32 dy;
}

struct Intercept {
    int32 frac;
    bool isaline;
    uint32 index;
}

/// @dev Shared original globals, intentionally reused across callbacks rather than copied.
/// @custom:source p_map.c and p_sight.c.
struct MapScratch {
    int32 opentop;
    int32 openbottom;
    int32 openrange;
    int32 lowfloor;
    int32[4] tmbbox;
    uint32 tmthing;
    uint32 tmflags;
    int32 tmx;
    int32 tmy;
    bool floatok;
    int32 tmfloorz;
    int32 tmceilingz;
    int32 tmdropoffz;
    uint32 ceilingline;
    uint32[8] spechit;
    int32 numspechit;
    int32 bestslidefrac;
    int32 secondslidefrac;
    uint32 bestslideline;
    uint32 secondslideline;
    uint32 slidemo;
    int32 tmxmove;
    int32 tmymove;
    uint32 linetarget;
    uint32 shootthing;
    uint32 usething;
    int32 shootz;
    int32 la_damage;
    int32 attackrange;
    int32 aimslope;
    int32 topslope;
    int32 bottomslope;
    int32 sightzstart;
    uint32[2] sightcounts;
    DivLine strace;
    int32 t2x;
    int32 t2y;
    uint32 bombsource;
    uint32 bombspot;
    int32 bombdamage;
    bool crushchange;
    bool nofit;
    bool onground; // p_user.c global, observed by height calculation.
    int32 bulletslope; // p_pspr.c global, shared by weapon callbacks.
    uint32 soundtarget; // p_enemy.c recursive sound flood target.
}

/// @custom:source p_maputl.c trace/intercepts/earlyout/ptflags globals.
struct PathScratch {
    DivLine trace;
    Intercept[128] intercepts;
    uint32 count;
    bool earlyout;
    int32 ptflags;
}

/// @dev Internal callbacks resolve original cyclic module calls. Never stored or externalized.
/// All hooks share the same GameContext memory alias; view permits lazy WAD resource reads.
struct GameHooks {
    function(GameContext memory, uint32, int32, int32) internal view returns (bool) tryMove;
    function(GameContext memory, uint32, int32, int32) internal view returns (bool) checkPosition;
    function(GameContext memory, uint32, int32, int32) internal view returns (bool) teleportMove;
    function(GameContext memory, uint32) internal view slideMove;
    function(GameContext memory, uint32, uint32) internal view returns (bool) checkSight;
    function(GameContext memory, uint32, uint32, int32) internal view returns (int32) aimLineAttack;
    function(GameContext memory, uint32, uint32, int32, int32, int32) internal view lineAttack;
    function(GameContext memory, uint32, uint32, int32) internal view radiusAttack;
    function(GameContext memory, uint32) internal view useLines;
    function(GameContext memory, uint32, bool) internal view returns (bool) changeSector;
    function(GameContext memory, int32, int32, int32, uint32) internal view returns (uint32) spawnMobj;
    function(GameContext memory, uint32) internal view removeMobj;
    function(GameContext memory, uint32, uint32) internal view returns (bool) setMobjState;
    function(GameContext memory, int32, int32, int32) internal view spawnPuff;
    function(GameContext memory, int32, int32, int32, int32) internal view spawnBlood;
    function(GameContext memory, uint32, uint32, uint32) internal view returns (uint32) spawnMissile;
    function(GameContext memory, uint32, uint32) internal view spawnPlayerMissile;
    function(GameContext memory, uint32, uint32, uint32, int32) internal view damageMobj;
    function(GameContext memory, uint32, uint32) internal view touchSpecialThing;
    function(GameContext memory, uint32, uint32) internal view actionMobj;
    function(GameContext memory, uint32, uint32, uint32) internal view actionPSprite;
    function(GameContext memory, uint32) internal view playerThink;
    function(GameContext memory, uint32) internal view movePsprites;
    function(GameContext memory, uint32) internal view setupPsprites;
    function(GameContext memory, uint32) internal view dropWeapon;
    function(GameContext memory) internal view respawnSpecials;
    function(GameContext memory, uint32, int32, uint32) internal view crossSpecialLine;
    function(GameContext memory, uint32, uint32, int32) internal view returns (bool) useSpecialLine;
    function(GameContext memory, uint32, uint32) internal view shootSpecialLine;
    function(GameContext memory, uint32) internal view playerSpecialSector;
    function(GameContext memory) internal view updateSpecials;
    function(GameContext memory) internal view spawnSpecials;
    function(GameContext memory, uint32, uint32) internal view noiseAlert;
    function(GameContext memory, uint32) internal view thinkerDispatch;
    // A_BossDeath/A_KeenDie pass synthetic original linedefs with only tag initialized.
    function(GameContext memory, int32, FloorType) internal view returns (bool) bossDoFloor;
    function(GameContext memory, int32, DoorType) internal view returns (bool) bossDoDoor;
    function(GameContext memory) internal view exitLevel;
}

struct GameContext {
    MapData map; // MUST alias state.map; assignment is a memory reference, not another loaded world.
    GameState state;
    RenderResources resources;
    GameDefinitions definitions;
    GameHooks hooks;
    MapScratch move;
    PathScratch path;
}
