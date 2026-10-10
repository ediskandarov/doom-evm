// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {IFrameProtocol} from "../evm/FrameProtocol.sol";
import {WadResources} from "../evm/WadResources.sol";
import {EpisodeStartup} from "../evm/EpisodeStartup.sol";
import {DoomGame} from "../evm/DoomGame.sol";
import {GameState, GameContext} from "../doom/p_game_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";
import {EpisodeStartupSnapshot as Snapshot} from "./EpisodeStartupSnapshot.sol";

/// @notice Isolated video companion to the unchanged verified SpeedrunProbe.
/// @dev Captures render from a memory copy; no render mutations enter saved gameplay.
contract SpeedrunVideoProbe is WadResources, IFrameProtocol {
    address public immutable driver = msg.sender;
    bool public initialized;
    GameState private saved;
    error InvalidReplay();
    event Observation(uint32 tic, bytes state);
    uint64 public frameId;
    event CaptureProof(
        uint32 indexed tic,
        bytes32 beforeState,
        bytes32 renderedState,
        uint32 validBefore,
        uint32 validAfter,
        uint32 mappedBefore,
        uint32 mappedAfter,
        uint64 renderGas
    );

    constructor(address[] memory chunks, bytes memory directory) WadResources(chunks, directory) {}

    function initialize() external {
        initializeProfile(1);
    }

    /// @notice Test-only selection of existing policies:0 strict,1 legacy initialized,2 Episode.
    function initializeProfile(uint8 profile) public {
        if (msg.sender != driver || initialized) revert InvalidReplay();
        if (profile > 2) revert InvalidReplay();
        (GameContext memory c,) = EpisodeStartup.initialize(_resourceView(), 1, 1, 0, false, profile != 0);
        c.state.nativeZone.canonicalPointerHighBytes = profile == 2;
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

    /// @dev Actual production renderer, standard Frame receipt; saved is never assigned.
    /// ML_MAPPED/validcount/zone/render bookkeeping may change only this memory copy.
    function capture(uint32 tic) external {
        if (msg.sender != driver || !initialized || saved.gametic != tic || tic == 0) revert InvalidReplay();
        GameState memory s = saved;
        GameContext memory c = DoomGame.load(_resourceView(), s);
        bytes32 beforeState = sha256(Snapshot.observe(c.state));
        uint32 validBefore = c.state.validcount;
        uint32 mappedBefore = mapped(c.state);
        uint256 began = gasleft();
        bytes memory pixels = DoomGame.render(c);
        uint64 renderGas = uint64(began - gasleft());
        if (pixels.length != 64000) revert InvalidReplay();
        emit CaptureProof(
            tic,
            beforeState,
            sha256(Snapshot.observe(c.state)),
            validBefore,
            c.state.validcount,
            mappedBefore,
            mapped(c.state),
            renderGas
        );
        emit Frame(++frameId, tic, 320, 200, pixels);
    }

    function mapped(GameState memory s) private pure returns (uint32 count) {
        for (uint256 i; i < s.map.lines.length; ++i) {
            if (s.map.lines[i].flags & 256 != 0) ++count; // original ML_MAPPED
        }
    }

    function snapshot() external view returns (bytes memory) {
        if (!initialized) revert InvalidReplay();
        GameState memory s = saved;
        return Snapshot.observe(s);
    }

    /// @notice Test-only rollback/persistence proof including zone and render bookkeeping.
    function savedDigest() external view returns (bytes32) {
        return sha256(abi.encode(saved));
    }
}
