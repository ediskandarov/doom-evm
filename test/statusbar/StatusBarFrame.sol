// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {ST_Stuff as ST, STState, STGraphics} from "../../src/doom/st_stuff.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {GameState, GameDefinitions, Player, GameConst} from "../../src/doom/p_game_state.sol";
import {IFrameProtocol} from "../../src/evm/FrameProtocol.sol";
import {DoomRenderer} from "../../src/evm/DoomRenderer.sol";
import {RenderContext} from "../../src/doom/r_render_state.sol";
import {R_Main} from "../../src/doom/r_main.sol";

// Dedicated verification consumer. Does not alter a production adapter or ABI.
contract StatusBarFrame is IFrameProtocol {
    event StatusPalette(uint64 indexed frameId, uint8 paletteIndex, bytes rgb);
    uint64 public frameId;

    function render(ResourceView memory source, bool world, bool legacy, uint32 sequence, int32 damage)
        external
    {
        VideoState memory v;
        if (world) {
            RenderContext memory c = DoomRenderer.initialize(source);
            c.rs.viewangle = 0;
            if (!legacy) R_Main.R_ExecuteSetViewSize(c.rs, 10, 0);
            DoomRenderer.render(c);
            v.screens[0] = c.rs.framebuffer;
        } else {
            v.screens[0] = new bytes(64000);
            for (uint256 i; i < 64000; ++i) {
                v.screens[0][i] = bytes1(uint8(i * 13 + (i / 320) * 7 + 19));
            }
        }
        STState memory s;
        STGraphics memory a;
        GameState memory g;
        GameDefinitions memory d;
        ST.ST_Init(s, v, a, source, 0);
        Player memory p = g.players[0];
        p.health = 100;
        p.readyweapon = 1;
        p.weaponowned[0] = true;
        p.weaponowned[1] = true;
        p.ammo[0] = 50;
        p.maxammo = [int32(200), 50, 300, 50];
        p.attacker = GameConst.NULL;
        p.damagecount = damage;
        int32[9] memory ammo = [int32(5), 0, 1, 0, 3, 2, 2, 5, 1];
        for (uint256 i; i < 9; ++i) {
            d.weaponinfo[i].ammo = ammo[i];
        }
        ST.ST_Start(s, a, g, d);
        ST.ST_Ticker(s, g, d);
        ST.ST_Drawer(s, a, v, g, d, legacy, false, false);
        uint64 id = ++frameId;
        emit StatusPalette(id, uint8(uint32(s.st_palette)), s.paletteRGB);
        emit Frame(id, sequence, 320, 200, v.screens[0]);
    }
}
