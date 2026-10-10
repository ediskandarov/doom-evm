// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {STStuffTest} from "../unit/st_stuff.t.sol";
import {DoomUI, UIState} from "../../src/evm/DoomUI.sol";
import {ST_Stuff, STGraphics} from "../../src/doom/st_stuff.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {GameContext, GameState, Mobj} from "../../src/doom/p_game_state.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";

/// @dev Controlled native vectors exercise the production consumer's storage and
/// borrowed graphics boundary. Ordinary gameplay/Frame integration is a separate Anvil gate.
contract ProductionUIAdapterTest is STStuffTest {
    UIState private savedUI;
    GameState private savedGame;

    function consumerRow(ResourceView memory r, int32[36] memory a, bool first)
        external
        returns (int32[24] memory values, bytes32 frame, bytes32 palette)
    {
        GameContext memory c;
        c.state = savedGame;
        c.definitions = definitions();
        c.resources.source = r;
        UIState memory u = savedUI;
        if (first) {
            c.state.mobjs = new Mobj[](2);
            c.state.renderFramebuffer = new bytes(64000);
            for (uint256 i; i < 64000; ++i) {
                c.state.renderFramebuffer[i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
            }
        }
        input(c.state, u.status, a);
        if (first) {
            STGraphics memory assets;
            VideoState memory video;
            ST_Stuff.ST_Init(u.status, video, assets, r, 0);
            ST_Stuff.ST_Start(u.status, assets, c.state, c.definitions);
            u.enabled = true;
        }
        require(a[0] <= 2, "supported controlled vector operation");
        if (a[0] != 2) DoomUI.tick(u, c);
        if (a[0] != 1) {
            u.fullscreen = a[25] != 0;
            u.refresh = a[26] != 0;
            DoomUI.erase(u);
            DoomUI.drawStatus(u, c);
        }
        values = snapshot(u.status, c.state, c.definitions);
        frame = sha256(c.state.renderFramebuffer);
        palette = sha256(u.status.paletteRGB.length == 0 ? new bytes(768) : u.status.paletteRGB);
        DoomUI.releaseGraphics(u);
        savedUI = u;
        savedGame = c.state;
        require(
            savedUI.status.w_faces.p.length == 0 && savedUI.status.w_ready.p.length == 0,
            "immutable graphics not duplicated in storage"
        );
    }

    function consumerCompare(string memory suite, uint256 limit) private {
        ResourceView memory r = source();
        bytes memory cases =
            vm.readFileBinary(string.concat("test/fixtures/phase4_statusbar/", suite, ".bin"));
        uint256 count = cases.length / 336;
        if (count > limit) count = limit;
        for (uint256 row; row < count; ++row) {
            uint256 base = row * 336;
            int32[36] memory a;
            for (uint256 j; j < 36; ++j) {
                a[j] = be32(cases, base + j * 4);
            }
            (int32[24] memory values, bytes32 frame, bytes32 palette) = this.consumerRow(r, a, row == 0);
            for (uint256 j; j < 24; ++j) {
                int32 expected = be32(cases, base + 144 + j * 4);
                if (values[j] != expected) revert StateMismatch(row, j, expected, values[j]);
            }
            require(frame == digest(cases, base + 240), "production consumer all native pixels");
            require(palette == digest(cases, base + 304), "production consumer native palette");
        }
    }

    function testConsumerPersistentInventoryAndOriginalStaleKeys() public {
        // Single-player sequence through every weapon, card/skull priority,
        // original stale-key behavior, refresh, grin and backpack capacity.
        consumerCompare("inventory", 22);
    }

    function testConsumerPersistentAttackFaceAndRelease() public {
        consumerCompare("firing", type(uint256).max);
    }

    function testConsumerPersistentDamageDirectionsAndPain() public {
        consumerCompare("directions", type(uint256).max);
    }
}
