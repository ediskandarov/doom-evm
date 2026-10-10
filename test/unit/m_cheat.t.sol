// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {CheatSequence, M_Cheat} from "../../src/doom/m_cheat.sol";
import {CheatState, ST_Cheats} from "../../src/doom/st_cheats.sol";
import {GameContext, GameConst, PlayerState} from "../../src/doom/p_game_state.sol";
import {GameflowState} from "../../src/doom/g_game.sol";
import {CheatFixture} from "../../src/support/CheatFixture.sol";

interface CheatVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
}

contract MCheatTest {
    CheatVm constant vm = CheatVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function word(bytes memory b, uint256 p) private pure returns (uint32 n) {
        for (uint256 i; i < 4; ++i) {
            n = (n << 8) | uint8(b[p + i]);
        }
    }

    function runRange(uint256 low, uint256 high) private view {
        bytes memory b = vm.readFileBinary("test/fixtures/phase4_cheats/vectors.bin");
        uint256 count = word(b, 0);
        uint256 at = 4;
        for (uint256 row; row < count; ++row) {
            int32[8] memory cfg;
            for (uint256 j; j < 8; ++j) {
                cfg[j] = int32(word(b, at));
                at += 4;
            }
            uint256 n = word(b, at);
            at += 4;
            if (row < low || row >= high) {
                at += n * 48;
                continue;
            }
            GameContext memory c = CheatFixture.fresh(cfg);
            GameflowState memory f;
            CheatState memory s;
            ST_Cheats.initialize(s);
            for (uint256 eventId; eventId < n; ++eventId) {
                uint8 typ = uint8(word(b, at));
                int32 key = int32(word(b, at + 4));
                bool active = word(b, at + 8) != 0;
                int32 dm = int32(word(b, at + 12));
                at += 16;
                bytes32 expected;
                assembly ("memory-safe") { expected := mload(add(add(b, 32), at)) }
                at += 32;
                require(!ST_Cheats.ST_Responder(c, f, s, typ, key), "ST consumed");
                ST_Cheats.AM_CheckCheat(s, typ, key, active, dm);
                require(
                    sha256(CheatFixture.snapshot(c, f, s)) == expected,
                    string.concat("native row ", vm.toString(row), " event ", vm.toString(eventId))
                );
            }
        }
        require(at == b.length, "fixture framing");
    }

    function testNativeRecognitionAndEffects() public view {
        runRange(0, 64);
    }

    function testNativeRestrictionsAndPowers() public view {
        runRange(64, 78);
    }

    function testNativeWarpValidation() public view {
        runRange(78, 130);
    }

    function testNativeMixedStreams() public view {
        runRange(130, 150);
    }

    function testNativePrimitiveAllByteValuesAndParameters() public view {
        bytes memory b = vm.readFileBinary("test/fixtures/phase4_cheats/primitive.bin");
        uint256 count = word(b, 0);
        uint256 at = 4;
        for (uint256 row; row < count; ++row) {
            bytes memory sequence = new bytes(10);
            for (uint256 i; i < 10; ++i) {
                sequence[i] = b[at + i];
            }
            at += 10;
            CheatSequence memory s = CheatSequence(sequence, word(b, at));
            uint8 key = uint8(word(b, at + 4));
            bool get = word(b, at + 8) != 0;
            at += 12;
            bytes32 expected;
            assembly ("memory-safe") { expected := mload(add(add(b, 32), at)) }
            at += 32;
            bool rc = M_Cheat.cht_CheckCheat(s, key);
            bytes memory param;
            if (get) param = M_Cheat.cht_GetParam(s);
            bytes memory snapshot = abi.encodePacked(
                uint32(rc ? 1 : 0),
                s.cursor,
                uint32(s.sequence.length),
                s.sequence,
                uint32(param.length),
                param
            );
            require(sha256(snapshot) == expected, string.concat("primitive ", vm.toString(row)));
        }
        require(at == b.length);
    }

    function testScramblePermutation() public pure {
        bool[256] memory seen;
        for (uint256 i; i < 256; ++i) {
            uint8 a = uint8(i);
            uint8 b = M_Cheat.scramble(a);
            uint8 expected = uint8(
                ((i & 1) << 7) + ((i & 2) << 5) + (i & 4) + ((i & 8) << 1) + ((i & 16) >> 1) + (i & 32)
                    + ((i & 64) >> 5) + ((i & 128) >> 7)
            );
            require(b == expected && !seen[b]);
            seen[b] = true;
        }
    }

    function testMismatchConsumesWithoutRetry() public pure {
        CheatSequence memory s = CheatSequence(hex"b22626aa26ff", 0);
        require(!M_Cheat.cht_CheckCheat(s, 105));
        require(s.cursor == 1);
        require(!M_Cheat.cht_CheckCheat(s, 105));
        require(s.cursor == 0);
        require(!M_Cheat.cht_CheckCheat(s, 100));
        require(s.cursor == 0);
    }

    function testParameterSlotsAndGetParam() public pure {
        CheatSequence memory s = CheatSequence(hex"b226e236a66e010000ff", 0);
        bytes memory input = bytes("idclev19");
        for (uint256 i; i < input.length; ++i) {
            require(M_Cheat.cht_CheckCheat(s, uint8(input[i])) == (i == input.length - 1));
        }
        require(s.cursor == 0 && s.sequence[7] == 0x31 && s.sequence[8] == 0x39);
        require(keccak256(M_Cheat.cht_GetParam(s)) == keccak256(hex"313900"));
        require(s.sequence[7] == 0 && s.sequence[8] == 0);
    }

    function testEmbeddedNulClearsOnlyVisitedParameter() public pure {
        CheatSequence memory s = CheatSequence(hex"b226e236a66e010039ff", 0);
        require(keccak256(M_Cheat.cht_GetParam(s)) == keccak256(hex"00"));
        require(s.sequence[8] == 0x39);
    }

    function testMarkerKeySkipsNextSlotExactlyLikeC() public pure {
        CheatSequence memory s = CheatSequence(hex"010000ff", 1);
        require(!M_Cheat.cht_CheckCheat(s, 0xff));
        require(s.cursor == 2 && s.sequence[1] == 0xff);
        require(M_Cheat.cht_CheckCheat(s, 0));
        require(s.cursor == 0);
    }

    function testGodNullMobjAndUnrelatedFlags() public pure {
        GameContext memory c = CheatFixture.fresh([int32(0), 0, 4, 0, 0, -7, 29, 0]);
        GameflowState memory f;
        CheatState memory s;
        c.state.players[0].cheats = GameConst.CF_NOCLIP | GameConst.CF_NOMOMENTUM;
        bytes memory input = bytes("iddqdiddqd");
        for (uint256 i; i < input.length; ++i) {
            ST_Cheats.ST_Responder(c, f, s, 0, int32(uint32(uint8(input[i]))));
        }
        require(c.state.players[0].health == 100 && c.state.mobjs[0].health == 29);
        require(c.state.players[0].cheats == 5 && c.state.players[0].mo == GameConst.NULL);
    }

    function testPositionFormattingZeroAndUnsignedTwosComplement() public pure {
        GameContext memory c = CheatFixture.fresh([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        GameflowState memory f;
        CheatState memory s;
        c.state.mobjs[0].angle = 0;
        c.state.mobjs[0].x = 0;
        c.state.mobjs[0].y = 0;
        bytes memory input = bytes("idmypos");
        for (uint256 i; i < input.length; ++i) {
            ST_Cheats.ST_Responder(c, f, s, 0, int32(uint32(uint8(input[i]))));
        }
        require(keccak256(bytes(s.positionMessage)) == keccak256("ang=0x0;x,y=(0x0,0x0)"));
        c.state.mobjs[0].angle = 0xffffffff;
        c.state.mobjs[0].x = -1;
        c.state.mobjs[0].y = type(int32).min;
        for (uint256 i; i < input.length; ++i) {
            ST_Cheats.ST_Responder(c, f, s, 0, int32(uint32(uint8(input[i]))));
        }
        require(
            keccak256(bytes(s.positionMessage)) == keccak256("ang=0xffffffff;x,y=(0xffffffff,0x80000000)")
        );
        require(keccak256(bytes(c.state.players[0].message)) == keccak256(bytes(s.positionMessage)));
    }

    function testUndefinedEarlyNulWarpDoesNotScheduleLevel() public pure {
        GameContext memory c = CheatFixture.fresh([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        GameflowState memory f;
        CheatState memory s;
        bytes memory input = hex"6964636c65760039";
        for (uint256 i; i < input.length; ++i) {
            ST_Cheats.ST_Responder(c, f, s, 0, int32(uint32(uint8(input[i]))));
        }
        require(
            c.state.gameaction == 0 && s.sequences[14].sequence[7] == 0 && s.sequences[14].sequence[8] == 0x39
        );
    }

    function testNoCaseFoldingMusicOrTickFiltering() public pure {
        GameContext memory c = CheatFixture.fresh([int32(0), 0, 4, 0, 1, 37, 29, 0]);
        GameflowState memory f;
        CheatState memory s;
        c.state.paused = true;
        c.state.players[0].playerstate = PlayerState.dead;
        bytes memory input = bytes("IDDQD idmus11 iddqd");
        for (uint256 i; i < input.length; ++i) {
            ST_Cheats.ST_Responder(c, f, s, 0, int32(uint32(uint8(input[i]))));
        }
        require(c.state.players[0].cheats == 2 && c.state.players[0].health == 100);
    }
}
