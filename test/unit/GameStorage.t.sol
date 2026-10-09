// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {GameState, GameContext, ThinkerKind, DoorType, GameConst} from "../../src/doom/p_game_state.sol";
import {P_Heap} from "../../src/doom/p_heap.sol";
import {P_Tick} from "../../src/doom/p_tick.sol";
import {Sector} from "../../src/doom/r_defs.sol";
import {RenderContext} from "../../src/doom/r_render_state.sol";
import {R_Plane} from "../../src/doom/r_plane.sol";

contract GameStorageTest {
    GameState private saved;

    function testPersistentGlobalsAndAliasesThroughStorageRoundTrip() public {
        GameContext memory c;
        c.state.map.sectors = new Sector[](1);
        c.map = c.state.map;
        c.move = c.state.move;
        c.path = c.state.path;
        c.map.sectors[0].floorheight = -8 * 65536;
        c.move.onground = true;
        c.move.attackrange = 64 * 65536;
        c.path.trace.x = 7 * 65536;
        c.state.texturetranslation = new uint32[](2);
        c.state.flattranslation = new uint32[](2);
        c.resources.texturetranslation = c.state.texturetranslation;
        c.resources.flattranslation = c.state.flattranslation;
        c.resources.texturetranslation[0] = 1;
        c.resources.flattranslation[1] = 1;
        c.state.renderPlane.cachedheight = new int32[](200);
        c.state.renderPlane.cacheddistance = new int32[](200);
        c.state.renderPlane.cachedxstep = new int32[](200);
        c.state.renderPlane.cachedystep = new int32[](200);
        c.state.renderPlane.spanstart = new int32[](200);
        c.state.renderPlane.cachedheight[3] = 17;
        c.state.renderPlane.cacheddistance[3] = 123;
        c.state.renderPlane.cachedxstep[3] = -456;
        c.state.renderPlane.cachedystep[3] = 789;
        c.state.renderPlane.spanstart[3] = 11;
        c.state.renderWall.rw_scalestep = -33;
        c.state.renderFramebuffer = new bytes(64000);
        c.state.renderFramebuffer[31999] = 0xde;
        c.state.renderFuzzpos = 17;
        c.state.renderFramecount = 28;
        c.state.players[0].message = "source game message";
        uint32 actor = P_Heap.allocateMobj(c.state);
        c.state.mobjs[actor].x = -77 * 65536;
        c.state.mobjs[actor].target = GameConst.NULL;
        c.state.mobjs[actor].spawnpoint.x = -19;
        c.state.mobjs[actor].allocated = true;
        P_Tick.P_InitThinkers(c.state);
        c.state.mobjs[actor].thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.mobj, actor);
        uint32 door = P_Heap.allocateDoor(c.state);
        c.state.doors[door].doorType = DoorType.close30ThenOpen;
        c.state.doors[door].sector = 0;
        c.state.doors[door].direction = -1;
        c.state.doors[door].thinker = P_Tick.P_AddThinker(c.state, ThinkerKind.door, door);
        c.path.intercepts[0].frac = 123;
        c.path.intercepts[0].index = actor;
        c.path.count = 1;
        saved = c.state;

        GameContext memory next;
        next.state = saved;
        next.map = next.state.map;
        next.move = next.state.move;
        next.path = next.state.path;
        next.resources.texturetranslation = next.state.texturetranslation;
        next.resources.flattranslation = next.state.flattranslation;
        require(next.map.sectors[0].floorheight == -8 * 65536, "world storage");
        require(next.move.onground && next.move.attackrange == 64 * 65536, "original tic globals");
        require(next.path.trace.x == 7 * 65536, "path globals");
        require(
            next.resources.texturetranslation[0] == 1 && next.resources.flattranslation[1] == 1,
            "translations"
        );
        require(next.state.renderWall.rw_scalestep == -33, "wall globals");
        require(next.state.renderFuzzpos == 17 && next.state.renderFramecount == 28, "render counters");
        require(next.state.renderFramebuffer[31999] == 0xde, "original screens0");
        require(
            keccak256(bytes(next.state.players[0].message)) == keccak256("source game message"),
            "nested player"
        );

        require(next.state.mobjCount == 1 && next.state.mobjs[actor].x == -77 * 65536, "actor pool");
        require(
            next.state.mobjs[actor].target == GameConst.NULL && next.state.mobjs[actor].spawnpoint.x == -19,
            "actor fields"
        );
        require(next.state.mobjs[actor].allocated && next.state.mobjs[actor].thinker == 1, "actor identity");
        require(next.state.thinkers[0].next == 1 && next.state.thinkers[1].next == 2, "live thinker links");
        require(next.state.thinkers[2].prev == 1 && next.state.thinkers[2].next == 0, "thinker tail");
        require(
            next.state.doors[door].doorType == DoorType.close30ThenOpen
                && next.state.doors[door].direction == -1,
            "world payload"
        );
        require(next.path.count == 1 && next.path.intercepts[0].frac == 123, "nested path array");
        RenderContext memory render;
        render.rs.width = 320;
        render.rs.height = 200;
        render.rs.centerxfrac = 160 * 65536;
        render.plane = next.state.renderPlane;
        R_Plane.R_ClearPlanes(render);
        require(next.state.renderPlane.cachedheight[3] == 0, "original height reset");
        require(next.state.renderPlane.cacheddistance[3] == 123, "original distance retained");
        require(
            next.state.renderPlane.cachedxstep[3] == -456 && next.state.renderPlane.cachedystep[3] == 789,
            "steps retained"
        );
        require(next.state.renderPlane.spanstart[3] == 11, "span starts retained");
        next.move.onground = false;
        next.resources.texturetranslation[0] = 0;
        next.map.sectors[0].floorheight = 5 * 65536;
        saved = next.state;
        require(!saved.move.onground && saved.texturetranslation[0] == 0, "aliased changes persisted");
        require(saved.map.sectors[0].floorheight == 5 * 65536, "world alias persisted");
    }
}
