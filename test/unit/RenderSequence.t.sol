// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {R_Main} from "../../src/doom/r_main.sol";
import {RenderContext} from "../../src/doom/r_render_state.sol";
import {RenderHooks} from "../../src/doom/r_render_hooks.sol";
import {Node} from "../../src/doom/r_defs.sol";

/// @notice Integration-adapter call contract. Full native pixel gates prove genuine callbacks.
contract RenderSequenceTest {
    function clearClip(RenderContext memory c) internal pure {
        require(c.rs.framecount == 1 && c.rs.validcount == 2, "setup must precede clears");
        require(c.rs.viewx == 123 && c.rs.viewy == -456 && c.rs.viewz == 789, "camera inputs");
        require(c.rs.fixedcolormap == 3 && c.rs.scalelightfixed.length == 48, "fixed lights set up");
        require(c.rs.sscount == 0, "setup resets subsector count");
        c.rs.framebuffer[0] = 0x01;
    }

    function clearSegs(RenderContext memory c) internal pure {
        require(c.rs.framebuffer[0] == 0x01);
        c.rs.framebuffer[0] = 0x02;
    }

    function clearPlanes(RenderContext memory c) internal pure {
        require(c.rs.framebuffer[0] == 0x02);
        c.rs.framebuffer[0] = 0x03;
    }

    function clearSprites(RenderContext memory c) internal pure {
        require(c.rs.framebuffer[0] == 0x03);
        c.rs.framebuffer[0] = 0x04;
    }

    function bsp(RenderContext memory c, int32 root) internal pure {
        require(root == int32(uint32(c.map.nodes.length)) - 1, "original last-node root");
        require(c.rs.framebuffer[0] == 0x04);
        c.rs.framebuffer[0] = 0x05;
    }

    function planes(RenderContext memory c) internal pure {
        require(c.rs.framebuffer[0] == 0x05);
        c.rs.framebuffer[0] = 0x06;
    }

    function masked(RenderContext memory c) internal pure {
        require(c.rs.framebuffer[0] == 0x06);
        c.rs.framebuffer[0] = 0x07;
    }

    function check(uint256 nodes) private view {
        RenderContext memory c;
        c.rs.viewx = 123;
        c.rs.viewy = -456;
        c.rs.viewz = 789;
        c.rs.fixedcolormap = 3;
        c.rs.validcount = 1;
        c.rs.sscount = 99;
        c.rs.framebuffer = new bytes(1);
        c.map.nodes = new Node[](nodes);
        RenderHooks memory hooks =
            RenderHooks(clearClip, clearSegs, clearPlanes, clearSprites, bsp, planes, masked);
        R_Main.R_RenderPlayerView(c, hooks);
        require(c.rs.framebuffer[0] == 0x07, "complete original pass sequence");
    }

    function testOriginalPassSequenceAndZeroNodeRoot() public view {
        check(0);
        check(3);
    }
}
