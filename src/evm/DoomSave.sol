// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {P_Saveg} from "../doom/p_saveg.sol";
import {GameState} from "../doom/p_game_state.sol";
import {UIState} from "./DoomUI.sol";
import {InputRuntimeState} from "./InputProtocol.sol";
import {EpisodeState} from "./EpisodeRuntime.sol";
import {ResourceIdentity} from "./ResourceTypes.sol";

struct SaveSlot {
    uint64 revision;
    uint64 gametic;
    int32 leveltime;
    int32 skill;
    int32 episode;
    int32 map;
    int32 gamemode;
    uint8 memoryPolicy;
    bytes32 schema;
    bytes32 engine;
    bytes32 resource;
    bytes32 digest;
    bytes description;
    bytes data;
}

struct SaveSlotMetadata {
    bool occupied;
    bool compatible;
    uint64 revision;
    uint64 gametic;
    int32 leveltime;
    int32 skill;
    int32 episode;
    int32 map;
    int32 gamemode;
    uint8 memoryPolicy;
    uint32 byteLength;
    bytes32 schema;
    bytes32 engine;
    bytes32 resource;
    bytes32 digest;
    bytes description;
}

/// @notice Contract-local six-slot archive registry; no external snapshot imports.
/// @dev Payload captures only the existing four authoritative state roots.
/// Transport counters, registry, WAD addresses and menu navigation are excluded.
library DoomSave {
    error InvalidSaveSlot();
    error SaveRevisionMismatch();
    error EmptySaveSlot();
    error IncompatibleSave();
    error InvalidSaveDigest();
    error InvalidSaveState();

    function resourceHash(ResourceIdentity memory identity) internal pure returns (bytes32) {
        return keccak256(abi.encode(identity));
    }

    function compatible(SaveSlot storage slot, bytes32 resource, uint8 policy) internal view returns (bool) {
        return slot.revision != 0 && slot.schema == P_Saveg.schemaHash()
            && slot.engine == address(this).codehash && slot.resource == resource
            && slot.memoryPolicy == policy;
    }

    function metadata(SaveSlot storage s, bytes32 resource, uint8 policy)
        internal
        view
        returns (SaveSlotMetadata memory m)
    {
        m = SaveSlotMetadata(
            s.revision != 0,
            compatible(s, resource, policy),
            s.revision,
            s.gametic,
            s.leveltime,
            s.skill,
            s.episode,
            s.map,
            s.gamemode,
            s.memoryPolicy,
            uint32(s.data.length),
            s.schema,
            s.engine,
            s.resource,
            s.digest,
            s.description
        );
    }

    function save(
        SaveSlot storage slot,
        GameState storage g,
        UIState storage u,
        InputRuntimeState storage i,
        EpisodeState storage e,
        bytes memory description,
        uint64 expectedRevision,
        bytes32 resource,
        uint8 policy
    ) internal returns (bytes32 digest) {
        if (slot.revision != expectedRevision) revert SaveRevisionMismatch();
        if (
            g.gamestate != 0 || g.gameaction != 0 || !i.flow.initialized || !i.flow.usergame || g.netgame
                || g.demoplayback || g.deathmatch != 0
        ) revert InvalidSaveState();
        bytes memory data = P_Saveg.P_Archive(g, u, i, e);
        digest = sha256(data);
        slot.data = data;
        slot.description = description;
        ++slot.revision;
        slot.gametic = g.gametic;
        slot.leveltime = g.leveltime;
        slot.skill = g.gameskill;
        slot.episode = g.gameepisode;
        slot.map = g.gamemap;
        slot.gamemode = g.gamemode;
        slot.memoryPolicy = policy;
        slot.schema = P_Saveg.schemaHash();
        slot.engine = address(this).codehash;
        slot.resource = resource;
        slot.digest = digest;
    }

    function load(
        SaveSlot storage slot,
        GameState storage g,
        UIState storage u,
        InputRuntimeState storage i,
        EpisodeState storage e,
        uint64 expectedRevision,
        bytes32 resource,
        uint8 policy
    ) internal {
        if (slot.revision == 0) revert EmptySaveSlot();
        if (slot.revision != expectedRevision) revert SaveRevisionMismatch();
        if (!compatible(slot, resource, policy)) revert IncompatibleSave();
        bytes memory data = slot.data;
        if (sha256(data) != slot.digest) revert InvalidSaveDigest();
        P_Saveg.P_UnArchive(g, u, i, e, data);
        // Metadata is independent redundancy; no setup/tic/render is dispatched.
        if (
            g.gametic != slot.gametic || g.leveltime != slot.leveltime || g.gameskill != slot.skill
                || g.gameepisode != slot.episode || g.gamemap != slot.map || g.gamemode != slot.gamemode
                || g.gamestate != 0 || g.gameaction != 0 || g.menuactive || i.gamekeydown != 0
                || !i.flow.initialized || !i.flow.usergame
        ) revert InvalidSaveState();
    }
}
