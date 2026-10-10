// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {WadResources} from "../evm/WadResources.sol";
import {EpisodeStartup} from "../evm/EpisodeStartup.sol";
import {DoomGame} from "../evm/DoomGame.sol";
import {GameState, GameContext} from "../doom/p_game_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";
import {EpisodeStartupSnapshot as Snapshot} from "./EpisodeStartupSnapshot.sol";

/// @notice Isolated exact short-tic demo input host, using accepted engine libraries.
/// @dev E1M1 skill0 only; no rendering, progression, synthetic state or exit triggers.
contract SpeedrunProbe is WadResources {
    address public immutable driver = msg.sender;
    bool public initialized;
    GameState private saved;
    error InvalidReplay();
    event Observation(uint32 tic, bytes state);

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function initialize() external {
        if (msg.sender != driver || initialized) revert InvalidReplay();
        (GameContext memory c,) = EpisodeStartup.initialize(_resourceView(), 1, 1, 0, false, true);
        saved = c.state;
        initialized = true;
        emit Observation(0, Snapshot.observe(c.state));
    }

    /// @dev Verbatim demo bytes: int8 forward, int8 side, uint8 short angle, uint8 buttons.
    /// Angle decoding equals original G_ReadDemoTiccmd; one row is one P_Ticker.
    function advance(bytes calldata commands) external {
        if (msg.sender != driver || !initialized || commands.length == 0 || commands.length % 4 != 0) {
            revert InvalidReplay();
        }
        GameState memory s = saved;
        GameContext memory c = DoomGame.load(_resourceView(), s);
        for (uint256 pos; pos < commands.length; pos += 4) {
            if (c.state.gameaction != 0) revert InvalidReplay();
            Ticcmd memory cmd;
            cmd.forwardmove = int8(uint8(commands[pos]));
            cmd.sidemove = int8(uint8(commands[pos + 1]));
            cmd.angleturn = int16(uint16(uint8(commands[pos + 2])) << 8);
            cmd.buttons = uint8(commands[pos + 3]);
            DoomGame.tick(c, cmd);
            emit Observation(uint32(c.state.gametic), Snapshot.observe(c.state));
        }
        saved = c.state;
    }

    function snapshot() external view returns (bytes memory) {
        if (!initialized) revert InvalidReplay();
        GameState memory s = saved;
        return Snapshot.observe(s);
    }
}
