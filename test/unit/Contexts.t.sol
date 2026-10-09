// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

import {DoomType} from "../../src/doom/doomtype.sol";
import {RenderState} from "../../src/doom/r_state.sol";
import {DoomState} from "../../src/doom/doomstat.sol";

/// @notice Phase 0 Solidity semantics probes, not original C arithmetic ports or oracle tests.
contract ContextsTest {
    RenderState private savedRender;
    DoomState private savedGame;

    function modifyFrame(RenderState memory frame) internal pure {
        frame.viewx = -DoomType.FRACUNIT;
        frame.framebuffer[0] = 0xfe;
    }

    function modifyGame(DoomState storage game) internal {
        ++game.gametic;
    }

    function testInternalMemoryReferenceAndAssignmentAlias() public pure {
        RenderState memory frame;
        frame.width = 2;
        frame.height = 1;
        frame.framebuffer = hex"0102";
        modifyFrame(frame);
        require(frame.viewx == -65536 && frame.framebuffer[0] == 0xfe, "internal memory reference");
        RenderState memory aliasFrame = frame;
        aliasFrame.viewy = 65536;
        aliasFrame.framebuffer[1] = 0xab;
        require(frame.viewy == 65536 && frame.framebuffer[1] == 0xab, "memory assignment aliases");
    }

    function testStorageMemoryCopiesAreIndependent() public {
        savedRender.viewx = 123;
        savedRender.framebuffer = hex"1020";
        RenderState memory frame = savedRender;
        modifyFrame(frame);
        require(savedRender.viewx == 123 && savedRender.framebuffer[0] == 0x10, "storage to memory copy");
        savedRender = frame;
        frame.viewx = 456;
        frame.framebuffer[0] = 0x77;
        require(savedRender.viewx == -65536 && savedRender.framebuffer[0] == 0xfe, "memory to storage copy");
        savedRender.framebuffer[1] = 0x99;
        require(frame.framebuffer[1] == 0x20, "storage mutation independent");
    }

    function testInternalStorageReferencePersists() public {
        savedGame.gametic = 10;
        modifyGame(savedGame);
        require(savedGame.gametic == 11, "internal storage reference");
        DoomState memory copy = savedGame;
        copy.gametic = 99;
        require(savedGame.gametic == 11, "game memory copy");
    }

    function testSignedShiftDiffersFromDivision() public pure {
        int32 negative = -3;
        require(negative >> 1 == -2, "signed shift must sign extend");
        require(negative / 2 == -1, "signed division truncates toward zero");
        int32 minimum = type(int32).min;
        require(minimum >> 31 == -1, "minimum sign extension");
        require(int64(minimum) == -2147483648, "widening sign extension");
    }

    function testExplicitNarrowingAndWidenedProduct() public pure {
        int64 wider = 2147483648;
        require(int32(wider) == type(int32).min, "explicit cast discards high bits");
        wider = -2147483649;
        require(int32(wider) == type(int32).max, "negative narrowing");
        int32 operand = type(int32).min;
        int64 product = int64(operand) * int64(operand);
        require(product == 4611686018427387904, "signed int64 product fits");
        uint32 angle = type(uint32).max;
        unchecked {
            ++angle;
        }
        require(angle == 0, "explicit angle wrap");
    }

    function testNullSentinelAndRawBspFlagAreDistinct() public pure {
        require(DoomType.NULL_INDEX == 0xffffffff && DoomType.NULL_INDEX != 0, "index zero is valid");
        require(DoomType.NF_SUBSECTOR == 0x8000, "raw uint16 WAD BSP flag");
        uint16 rawChild = 0x8003;
        require(uint32(rawChild) & DoomType.NF_SUBSECTOR != 0, "subsector marker");
        require((uint32(rawChild) & ~DoomType.NF_SUBSECTOR) == 3, "raw child index decode");
        require(DoomType.FRACUNIT == int32(1) << DoomType.FRACBITS, "16.16 scale");
    }

    function testFuzzInt32NarrowingPreservesLowBits(int64 value) public pure {
        require(uint32(int32(value)) == uint32(uint64(value)), "narrowing low bits");
    }
}
