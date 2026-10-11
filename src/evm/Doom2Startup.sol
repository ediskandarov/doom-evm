// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {GameContext, GameState, GameConst, PlayerState} from "../doom/p_game_state.sol";
import {G_Game, GameflowState, GameflowHooks} from "../doom/g_game.sol";
import {ResourceView} from "../doom/r_data_types.sol";
import {RenderContext} from "../doom/r_render_state.sol";
import {R_Data} from "../doom/r_data.sol";
import {R_Things} from "../doom/r_things.sol";
import {Info} from "../doom/info.sol";
import {P_Setup} from "../doom/p_setup.sol";
import {Z_Zone} from "../doom/z_zone.sol";
import {DoomGame} from "./DoomGame.sol";
import {DoomZoneStartup} from "./DoomZoneStartup.sol";

/// @notice Independent, synchronous startup of the pinned commercial MAP01–MAP32.
/// @dev Adapter only: existing original-source libraries own all setup/spawning.
/// No production endpoint, tick, transition, UI or host-generated world is added.
library Doom2Startup {
    error UnsupportedSelection(int32 episode, int32 map, int32 skill);
    error ResourceIdentityMismatch();
    error ResourceDirectoryMismatch();
    error ResourceChunksMismatch();

    // Same v0 identity as WadResources; the v1 episode catalog does not change it.
    function validate(ResourceView memory source) internal view {
        if (
            source.identity.schemaVersion != 0
                || source.identity.wadSha256
                    != 0x10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255
                || source.identity.bundleSha256
                    != 0x775bc8b01d44c2fb1c3a68a79b9864c2f36ebbb29746d31e9ca600ae226af5ad
                || source.identity.paletteSha256
                    != 0xfd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb
                || source.identity.paletteVariant != 0 || source.byteLength != 14557275
                || source.lumps.length != 2919 || source.chunks.length != 889
        ) revert ResourceIdentityMismatch();
        bytes memory directory = new bytes(2919 * 16);
        for (uint256 i; i < source.lumps.length; ++i) {
            uint256 p = i * 16;
            for (uint256 j; j < 8; ++j) {
                directory[p + j] = source.lumps[i].name[j];
            }
            le32(directory, p + 8, source.lumps[i].offset);
            le32(directory, p + 12, source.lumps[i].length);
        }
        if (sha256(directory) != 0x2d91a39dcf822b968a3719ef79bc2a7880b634432522300c575a76b970022515) {
            revert ResourceDirectoryMismatch();
        }
        bytes memory scratch = new bytes(16385);
        bytes memory hashes = new bytes(889 * 32);
        for (uint256 i; i < source.chunks.length; ++i) {
            address chunk = source.chunks[i];
            uint256 size = i == 888 ? 8284 : 16385;
            if (chunk.code.length != size) revert ResourceChunksMismatch();
            // scratch owns16385 bytes; size <=16385. Each hash word lies inside
            // hashes[0:889*32]. The final shorter copy changes logical length only.
            assembly ("memory-safe") {
                mstore(scratch, size)
                extcodecopy(chunk, add(scratch, 32), 0, size)
            }
            bytes32 digest = sha256(scratch);
            assembly ("memory-safe") { mstore(add(add(hashes, 32), mul(i, 32)), digest) }
        }
        if (sha256(hashes) != 0x903d131f726847ec2afc79d24fa0a1c08d7c03fbacb135d23808d9a5b4a299c9) {
            revert ResourceChunksMismatch();
        }
    }

    function le32(bytes memory data, uint256 p, uint32 value) private pure {
        for (uint256 i; i < 4; ++i) {
            data[p + i] = bytes1(uint8(value >> (i * 8)));
        }
    }

    function initialize(
        ResourceView memory source,
        int32 episode,
        int32 map,
        int32 skill,
        bool nomonsters,
        bool deterministicInitialization
    ) internal view returns (GameContext memory c, GameflowState memory f) {
        // Exact selection domain, before G_InitNew's original menu clamping.
        if (episode != 1 || map < 1 || map > 32 || skill < 0 || skill > 4) {
            revert UnsupportedSelection(episode, map, skill);
        }
        validate(source);
        GameState memory s;
        s.gamemode = 2;
        s.gameskill = 2; // existing retail startup profile before G_InitNew
        s.nomonsters = nomonsters;
        s.playeringame[0] = true;
        s.validcount = 1;
        for (uint256 i; i < 4; ++i) {
            s.players[i].playerstate = PlayerState.reborn;
            s.players[i].mo = GameConst.NULL;
            s.players[i].attacker = GameConst.NULL;
            s.players[i].psprites[0].state = GameConst.NULL;
            s.players[i].psprites[1].state = GameConst.NULL;
        }
        s.move.tmthing = GameConst.NULL;
        s.move.ceilingline = GameConst.NULL;
        s.move.bestslideline = GameConst.NULL;
        s.move.secondslideline = GameConst.NULL;
        s.move.slidemo = GameConst.NULL;
        s.move.linetarget = GameConst.NULL;
        s.move.shootthing = GameConst.NULL;
        s.move.usething = GameConst.NULL;
        s.move.bombspot = GameConst.NULL;
        s.move.bombsource = GameConst.NULL;
        s.move.soundtarget = GameConst.NULL;
        c = DoomGame.load(source, s); // binds accepted original gameplay hooks, no level load
        // load restores stored translations. A fresh runtime has none: reproduce
        // the R_InitData identity arrays using its authenticated decoded counts.
        c.state.texturetranslation = new uint32[](c.resources.textures.length);
        c.state.flattranslation = new uint32[](c.resources.numflats);
        for (uint32 i; i < c.state.texturetranslation.length; ++i) {
            c.state.texturetranslation[i] = i;
        }
        for (uint32 i; i < c.state.flattranslation.length; ++i) {
            c.state.flattranslation[i] = i;
        }
        c.resources.texturetranslation = c.state.texturetranslation;
        c.resources.flattranslation = c.state.flattranslation;
        RenderContext memory renderer;
        renderer.resources = c.resources;
        R_Things.R_InitSprites(renderer, Info.load().spriteNames);
        c.state.nativeZone =
            Z_Zone.Z_Init(64 * 1024 * 1024, uint32(source.lumps.length + c.resources.textures.length));
        c.state.nativeZone.deterministicInitialization = deterministicInitialization;
        c.resources.nativeZone = c.state.nativeZone;
        DoomZoneStartup.replay(c.state.nativeZone, c.resources, renderer.sprite.definitions);
        P_Setup.P_Init(c);
        GameflowHooks memory h;
        h.setupLevel = setupLevel;
        h.checkHeap = checkHeap;
        h.flatNumForName = flat;
        h.textureNumForName = texture;
        G_Game.G_InitNew(c, f, h, skill, episode, map);
    }

    /// @dev Original P_SetupLevel's supplemental wminfo globals precede world setup.
    /// Production integration must bind ST_Start/HU_Start at the console spawn
    /// boundary; this world-only foundation retains the accepted no-UI profile.
    function setupLevel(GameContext memory c, GameflowState memory f) private view {
        f.wminfo.maxfrags = 0;
        f.wminfo.partime = 180;
        P_Setup.P_SetupLevel(c, c.state.gameepisode, c.state.gamemap, 0, c.state.gameskill);
        c.map = c.state.map;
        c.resources.nativeZone = c.state.nativeZone;
    }

    function checkHeap(GameContext memory c, GameflowState memory) private pure {
        Z_Zone.Z_CheckHeap(c.state.nativeZone);
    }

    function flat(GameContext memory c, bytes8 name) private pure returns (uint32) {
        return R_Data.R_FlatNumForName(c.resources, name);
    }

    function texture(GameContext memory c, bytes8 name) private pure returns (uint32) {
        return R_Data.R_TextureNumForName(c.resources, name);
    }
}
