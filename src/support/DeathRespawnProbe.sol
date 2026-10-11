// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Doom} from "../evm/Doom.sol";
import {DoomGame} from "../evm/DoomGame.sol";
import {GameContext, GameConst} from "../doom/p_game_state.sol";
import {P_Info} from "../doom/p_info.sol";
import {EpisodeStartupSnapshot} from "./EpisodeStartupSnapshot.sol";

/// @dev Explicit controlled native-oracle setup only; never packaged as a browser game.
library DeathScenario {
    error InvalidScenario();

    function configure(GameContext memory c, uint8 op) internal view {
        uint32 id = c.state.players[0].mo;
        if (op == 1) {
            uint32 enemy = c.hooks
                .spawnMobj(
                    c,
                    c.state.mobjs[id].x + 64 * 65536,
                    c.state.mobjs[id].y,
                    GameConst.ONFLOORZ,
                    P_Info.MT_POSSESSED
                );
            if (!c.hooks.checkPosition(c, enemy, c.state.mobjs[enemy].x, c.state.mobjs[enemy].y)) {
                revert InvalidScenario();
            }
            c.state.mobjs[enemy].angle = 0x80000000;
            c.state.mobjs[enemy].target = id;
            c.hooks.setMobjState(c, enemy, uint32(c.definitions.mobjinfo[P_Info.MT_POSSESSED].seestate));
            c.state.players[0].health = 3;
            c.state.mobjs[id].health = 3;
        } else if (op == 2) {
            c.state.players[0].health = 3;
            c.state.mobjs[id].health = 3;
            c.state.leveltime = 0;
            c.state.sectors[c.map.subsectors[c.state.mobjs[id].subsector].sector].special = 7;
        } else if (op == 3) {
            c.state.players[0].armorpoints = 200;
            c.state.players[0].armortype = 2;
            c.state.players[0].backpack = true;
            for (uint256 i; i < 9; ++i) {
                c.state.players[0].weaponowned[i] = true;
            }
            for (uint256 i; i < 4; ++i) {
                c.state.players[0].maxammo[i] *= 2;
                c.state.players[0].ammo[i] = c.state.players[0].maxammo[i];
            }
            for (uint256 i; i < 6; ++i) {
                c.state.players[0].cards[i] = true;
            }
            c.state.players[0].powers[2] = 100;
            c.state.mobjs[id].flags |= GameConst.MF_SHADOW;
        } else {
            revert InvalidScenario();
        }
    }
}

contract DeathRespawnProbe is Doom {
    constructor(address[] memory chunks, bytes memory directory) Doom(chunks, directory) {}

    function configure(uint8 op) external {
        if (msg.sender != driver) revert NotDriver();
        GameContext memory c = DoomGame.load(_resourceView(), gameState);
        DeathScenario.configure(c, op);
        gameState = c.state;
    }

    function stateDigest() external view returns (bytes32) {
        return
            keccak256(
                abi.encode(gameState, inputRuntime, uiState, episodeState, menuState, inputSeq, frameId)
            );
    }

    function snapshot() external view returns (bytes memory) {
        return EpisodeStartupSnapshot.observe(gameState);
    }

    function zoneSnapshot() external view returns (bytes memory) {
        return EpisodeStartupSnapshot.zone(gameState.nativeZone);
    }
}
