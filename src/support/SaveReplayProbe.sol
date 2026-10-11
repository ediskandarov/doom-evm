// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ProductionWadResources} from "../evm/ProductionWadResources.sol";
import {DoomGame} from "../evm/DoomGame.sol";
import {DoomSave, SaveSlot} from "../evm/DoomSave.sol";
import {P_Saveg} from "../doom/p_saveg.sol";
import {GameContext, GameState, GameConst, PlatType} from "../doom/p_game_state.sol";
import {UIState} from "../evm/DoomUI.sol";
import {InputRuntimeState} from "../evm/InputProtocol.sol";
import {EpisodeState} from "../evm/EpisodeRuntime.sol";
import {EpisodeStartupSnapshot as Snapshot} from "./EpisodeStartupSnapshot.sol";
import {P_Info} from "../doom/p_info.sol";
import {P_Plats} from "../doom/p_plats.sol";
import {P_Pspr} from "../doom/p_pspr.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";

/// @notice Test-only direct-command original-C comparison host with the production archive.
/// @dev Fixture setup uses original P_* calls in authentic geometry, copied from
/// the accepted GameplayProbe scenarios. Never part of browser/production APIs.
contract SaveReplayProbe is ProductionWadResources {
    error InvalidScenario();
    GameState internal gameState;
    UIState internal uiState;
    InputRuntimeState internal inputRuntime;
    EpisodeState internal episodeState;
    SaveSlot[6] internal slots;
    event Observation(bytes state, bytes pixels);
    event Archive(uint8 operation, uint256 size, bytes32 digest, uint256 boundaryBytes);
    constructor(address[] memory chunks, bytes memory directory) ProductionWadResources(chunks, directory) {}

    function initialize(uint8 scenario) external {
        require(gameState.thinkerCount == 0);
        GameContext memory c = DoomGame.initializeNativeWithPolicy(_resourceView(), scenario == 4, true);
        c.state.nativeZone.canonicalPointerHighBytes = true;
        c.state.nativeZone.experimentalVirtualPointers = true;
        configure(c, scenario);
        gameState = c.state;
        inputRuntime.flow.initialized = true;
        inputRuntime.flow.usergame = true;
        emit Observation(Snapshot.observe(c.state), "");
    }

    function configure(GameContext memory c, uint8 scenario) private view {
        uint32 mo = c.state.players[0].mo;
        if (scenario == 4 || scenario == 5) {
            if (!c.hooks.teleportMove(c, mo, 832 * 65536, 576 * 65536)) revert InvalidScenario();
            c.state.mobjs[mo].z = c.state.mobjs[mo].floorz;
            c.state.mobjs[mo].angle = 0xc0000000;
        } else if (scenario != 0 && scenario != 7) {
            uint32 enemy = c.hooks
                .spawnMobj(
                    c,
                    c.state.mobjs[mo].x + 64 * 65536,
                    c.state.mobjs[mo].y,
                    GameConst.ONFLOORZ,
                    P_Info.MT_POSSESSED
                );
            if (!c.hooks.checkPosition(c, enemy, c.state.mobjs[enemy].x, c.state.mobjs[enemy].y)) {
                revert InvalidScenario();
            }
            c.state.mobjs[enemy].angle = 0x80000000;
            c.state.mobjs[enemy].target = mo;
            c.hooks.setMobjState(c, enemy, uint32(c.definitions.mobjinfo[P_Info.MT_POSSESSED].seestate));
            if (scenario == 2) {
                c.state.players[0].armorpoints = 100;
                c.state.players[0].armortype = 1;
            }
            if (scenario == 3) {
                c.state.players[0].health = 3;
                c.state.mobjs[mo].health = 3;
            }
        }
        if (scenario == 7) {
            c.state.sectors[0].tag = 9999;
            c.map.lines[0].tag = 9999;
            P_Plats.EV_DoPlat(c, 0, PlatType.perpetualRaise, 0);
            if (c.state.platCount != 1) revert InvalidScenario();
        }
        if (scenario == 6) {
            // Same explicit test setup as the independent original-C projectile host.
            // Original wp_missile=4, am_misl=3; no world or pixels are supplied.
            c.state.mobjs[mo].angle = 0;
            c.state.players[0].armorpoints = 200;
            c.state.players[0].armortype = 2;
            c.state.players[0].weaponowned[4] = true;
            c.state.players[0].readyweapon = 4;
            c.state.players[0].pendingweapon = P_Pspr.WP_NOCHANGE;
            c.state.players[0].ammo[3] = 6;
            c.hooks.setupPsprites(c, 0);
        }
    }

    function advance(Ticcmd calldata cmd, bool draw) external {
        GameContext memory c = DoomGame.load(_resourceView(), gameState);
        DoomGame.tick(c, cmd);
        bytes memory state = Snapshot.observe(c.state);
        bytes memory pixels;
        if (draw) pixels = DoomGame.render(c);
        gameState = c.state;
        emit Observation(state, pixels);
    }

    function save(uint8 slot) external {
        bytes32 digest = DoomSave.save(
            slots[slot],
            gameState,
            uiState,
            inputRuntime,
            episodeState,
            bytes("NATIVE REPLAY"),
            slots[slot].revision,
            DoomSave.resourceHash(resourceIdentity()),
            3
        );
        emit Archive(1, slots[slot].data.length, digest, memorySize());
    }

    function load(uint8 slot) external {
        DoomSave.load(
            slots[slot],
            gameState,
            uiState,
            inputRuntime,
            episodeState,
            slots[slot].revision,
            DoomSave.resourceHash(resourceIdentity()),
            3
        );
        emit Archive(2, slots[slot].data.length, slots[slot].digest, memorySize());
    }

    function digest() external returns (bytes32) {
        return sha256(P_Saveg.P_Archive(gameState, uiState, inputRuntime, episodeState));
    }

    function snapshot() external view returns (bytes memory) {
        return Snapshot.observe(gameState);
    }

    function memorySize() private view returns (uint256) {
        return gasleft();
    }
}
