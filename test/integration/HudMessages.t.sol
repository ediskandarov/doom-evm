// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {HudTestBase} from "../unit/hu_stuff.t.sol";
import {HU_Stuff, HudState} from "../../src/doom/hu_stuff.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {GameContext, GameConst, Mobj} from "../../src/doom/p_game_state.sol";
import {Line} from "../../src/doom/r_defs.sol";
import {P_Inter} from "../../src/doom/p_inter.sol";
import {P_Doors} from "../../src/doom/p_doors.sol";
import {P_Info} from "../../src/doom/p_info.sol";
import {IFrameProtocol} from "../../src/evm/FrameProtocol.sol";

interface HudLogVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

// Dedicated composition harness; no production adapter or shared engine changes.
contract HudMessagesTest is HudTestBase, IFrameProtocol {
    HudState private saved;
    string private pending;

    function remove(GameContext memory c, uint32 mo) internal pure {
        c.state.mobjs[mo].allocated = false;
    }

    function gameplay(uint32 kind, uint32 arg, int32 health, bytes[] memory f)
        external
        returns (string memory text, bytes32 hash)
    {
        GameContext memory c;
        c.definitions = P_Info.load();
        c.state.gamemode = 2;
        c.state.gameskill = 2;
        c.state.mobjs = new Mobj[](2);
        c.state.mobjs[0].player = 0;
        c.state.mobjs[0].health = health;
        c.state.mobjs[0].height = 56 * 65536;
        c.state.players[0].mo = 0;
        c.state.players[0].health = health;
        c.state.players[0].readyweapon = 1;
        c.state.players[0].maxammo = [int32(200), 50, 300, 50];
        c.hooks.removeMobj = remove;
        if (kind == 0) {
            c.state.mobjs[1].sprite = arg;
            c.state.mobjs[1].allocated = true;
            c.state.mobjs[1].flags = GameConst.MF_SPECIAL | GameConst.MF_COUNTITEM;
            P_Inter.P_TouchSpecialThing(c, 1, 0);
        } else {
            c.map.lines = new Line[](1);
            c.map.lines[0].special = int16(uint16(arg));
            P_Doors.EV_VerticalDoor(c, 0, 0);
        }
        text = c.state.players[0].message;
        HudState memory h;
        HU_Stuff.HU_Start(h, f, 1, 1, 1);
        HU_Stuff.HU_Ticker(h, c.state.players[0], true);
        require(bytes(c.state.players[0].message).length == 0, "player message consumed");
        VideoState memory v = freshVideo();
        HU_Stuff.HU_Drawer(h, v, false);
        hash = sha256(v.screens[0]);
        emit Frame(1, 0, 320, 200, v.screens[0]);
    }

    function testRealPickupAndLockedDoorNativeTextAndEvmPixels() public {
        bytes memory data = vm.readFileBinary("test/fixtures/phase4_hud/gameplay.bin");
        bytes[] memory f = HU_Stuff.HU_Init(resourceFonts(fonts()));
        uint256 pos = 4;
        uint32 count = word(data, 0);
        require(count == 44, "all pickup types, failed/full health, needy medikit and six locks");
        HudLogVm logvm = HudLogVm(address(vm));
        for (uint256 i; i < count; ++i) {
            uint32 kind = word(data, pos);
            uint32 arg = word(data, pos + 4);
            int32 health = int32(word(data, pos + 8));
            uint32 n = word(data, pos + 12);
            pos += 16;
            bytes memory text = slice(data, pos, n);
            pos += n;
            bytes32 expected = digest(data, pos);
            pos += 32;
            logvm.recordLogs();
            (string memory actual, bytes32 framehash) = this.gameplay(kind, arg, health, f);
            require(keccak256(bytes(actual)) == keccak256(text), "original gameplay text");
            require(framehash == expected, "original C producer + C HUD full framebuffer");
            HudLogVm.Log[] memory logs = logvm.getRecordedLogs();
            require(logs.length == 1, "one Frame");
            require(
                logs[0].topics[0] == keccak256("Frame(uint64,uint32,uint16,uint16,bytes)"),
                "frozen Frame protocol"
            );
            (uint16 w, uint16 h, bytes memory frame) = abi.decode(logs[0].data, (uint16, uint16, bytes));
            require(
                w == 320 && h == 200 && frame.length == 64000 && sha256(frame) == expected,
                "complete indexed8 EVM Frame"
            );
        }
        require(pos == data.length);
    }

    function saveHud(bytes[] memory f) external {
        HudState memory h;
        HU_Stuff.HU_Start(h, f, 1, 1, 1);
        cqueue(h, "protected", true);
        saved = h;
        pending = "next";
    }

    function cqueue(HudState memory h, string memory text, bool forced) private pure {
        // Same player message path; forced flag is owned by HUD consumers such as system/cheat callers.
        GameContext memory c;
        c.state.players[0].message = text;
        h.message_dontfuckwithme = forced;
        HU_Stuff.HU_Ticker(h, c.state.players[0], true);
    }

    function advanceHud(uint32 ticks)
        external
        returns (bytes32 hash, bool on, int32 counter, string memory waiting)
    {
        HudState memory h = saved;
        GameContext memory c;
        c.state.players[0].message = pending;
        for (uint32 i; i < ticks; ++i) {
            HU_Stuff.HU_Ticker(h, c.state.players[0], true);
        }
        VideoState memory v = freshVideo();
        HU_Stuff.HU_Drawer(h, v, false);
        hash = sha256(v.screens[0]);
        on = h.message.on;
        counter = h.message_counter;
        waiting = c.state.players[0].message;
        saved = h;
        pending = waiting;
    }

    function testHudStateSurvivesSeparateCallStorageRoundTrips() public {
        this.saveHud(fonts());
        (bytes32 before, bool on, int32 counter, string memory waiting) = this.advanceHud(139);
        require(
            on && counter == 1 && keccak256(bytes(waiting)) == keccak256("next"), "protected pending retained"
        );
        (bytes32 after_, bool nextOn, int32 nextCounter, string memory nextWaiting) = this.advanceHud(1);
        require(
            nextOn && nextCounter == 140 && bytes(nextWaiting).length == 0 && before != after_,
            "expiry consumes next message"
        );
        (, nextOn, nextCounter,) = this.advanceHud(140);
        require(!nextOn && nextCounter == 0, "expiry across storage");
    }

    function testDisabledHudCompositionPreservesLegacyFramebuffer() public pure {
        HudState memory h;
        VideoState memory v = freshVideo();
        bytes32 before = sha256(v.screens[0]);
        HU_Stuff.HU_Drawer(h, v, false);
        require(sha256(v.screens[0]) == before, "inactive HUD leaves full-screen pixels");
    }
}
