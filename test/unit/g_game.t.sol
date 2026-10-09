// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {Ticcmd, GameInputState, KeyboardInput} from "../../src/doom/d_ticcmd.sol";
import {G_Game} from "../../src/doom/g_game.sol";
import {InputProtocol} from "../../src/evm/InputProtocol.sol";

interface VmInput {
    function readFileBinary(string calldata path) external view returns (bytes memory);
}

contract GGameTest {
    VmInput constant vm = VmInput(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _word(bytes memory data, uint256 offset) private pure returns (uint32 result) {
        for (uint256 i; i < 4; ++i) {
            result = (result << 8) | uint8(data[offset + i]);
        }
    }

    function _fixture() private view returns (bytes memory data) {
        data = vm.readFileBinary("test/fixtures/phase3_input/vectors.bin");
        require(_word(data, 0) == 41007 && data.length == 4 + 41007 * 28, "oracle extent");
    }

    function _case(bytes memory data, uint256 index, GameInputState memory state) private pure {
        uint256 p = 4 + index * 28;
        require(state.turnheld == int32(_word(data, p + 4)), "sequence input state");
        Ticcmd memory cmd = InputProtocol.build(state, _word(data, p));
        require(state.turnheld == int32(_word(data, p + 8)), "C turnheld mismatch");
        require(int32(cmd.forwardmove) == int32(_word(data, p + 12)), "C forwardmove mismatch");
        require(int32(cmd.sidemove) == int32(_word(data, p + 16)), "C sidemove mismatch");
        require(int32(cmd.angleturn) == int32(_word(data, p + 20)), "C angleturn mismatch");
        require(uint32(cmd.buttons) == _word(data, p + 24), "C buttons mismatch");
        require(cmd.consistancy == 0 && cmd.chatchar == 0, "keyboard profile metadata");
    }

    function _batch(uint256 weapon) private view {
        bytes memory data = _fixture();
        GameInputState memory state;
        for (uint256 s; s < 4; ++s) {
            uint256 start = (s * 10 + weapon) * 1024;
            for (uint256 i = start; i < start + 1024; ++i) {
                state.turnheld = int32(_word(data, 4 + i * 28 + 4));
                _case(data, i, state);
            }
        }
    }

    function testOriginalCNoWeaponAllKeyboardMasksAndTurnStates() public view {
        _batch(0);
    }

    function testOriginalCWeapon1AllKeyboardMasksAndTurnStates() public view {
        _batch(1);
    }

    function testOriginalCWeapon2AllKeyboardMasksAndTurnStates() public view {
        _batch(2);
    }

    function testOriginalCWeapon3AllKeyboardMasksAndTurnStates() public view {
        _batch(3);
    }

    function testOriginalCWeapon4AllKeyboardMasksAndTurnStates() public view {
        _batch(4);
    }

    function testOriginalCWeapon5AllKeyboardMasksAndTurnStates() public view {
        _batch(5);
    }

    function testOriginalCWeapon6AllKeyboardMasksAndTurnStates() public view {
        _batch(6);
    }

    function testOriginalCWeapon7AllKeyboardMasksAndTurnStates() public view {
        _batch(7);
    }

    function testOriginalCWeapon8AllKeyboardMasksAndTurnStates() public view {
        _batch(8);
    }

    function testOriginalCIgnoredWeapon9AllKeyboardMasksAndTurnStates() public view {
        _batch(9);
    }

    function testOriginalCSequentialTurnAccelerationReleaseAndWeapons() public view {
        bytes memory data = _fixture();
        GameInputState memory state;
        for (uint256 i = 40960; i < 41007; ++i) {
            _case(data, i, state);
        }
    }

    function evaluate(uint32 held, int32 turnheld)
        external
        pure
        returns (Ticcmd memory cmd, int32 afterTurn)
    {
        GameInputState memory state = GameInputState(turnheld);
        cmd = InputProtocol.build(state, held);
        afterTurn = state.turnheld;
    }

    function _reject(uint32 held, int32 turnheld, bytes memory expected) private view {
        try this.evaluate(held, turnheld) returns (Ticcmd memory, int32) {
            revert("invalid command accepted");
        } catch (bytes memory actual) {
            require(keccak256(actual) == keccak256(expected), "wrong command rejection");
        }
    }

    function testRejectsReservedPacketBitsAndUndefinedWeaponRequests() public view {
        for (uint256 bit = 14; bit < 32; ++bit) {
            uint32 held = uint32(uint256(1) << bit);
            _reject(held, 0, abi.encodeWithSelector(InputProtocol.UnsupportedInputBits.selector, held));
        }
        for (uint8 weapon = 10; weapon < 16; ++weapon) {
            _reject(
                uint32(weapon) << 10,
                0,
                abi.encodeWithSelector(InputProtocol.InvalidWeaponRequest.selector, weapon)
            );
        }
    }

    function testRejectsInvalidTurnStateAndOriginalUndefinedCounterOverflow() public view {
        _reject(0, -1, abi.encodeWithSelector(G_Game.InvalidTurnState.selector, int32(-1)));
        _reject(
            16, type(int32).max, abi.encodeWithSelector(G_Game.InvalidTurnState.selector, type(int32).max)
        );
        (, int32 afterTurn) = this.evaluate(0, type(int32).max);
        require(afterTurn == 0, "defined reset rejected");
        (, afterTurn) = this.evaluate(16, type(int32).max - 1);
        require(afterTurn == type(int32).max, "defined increment rejected");
    }

    function testDirectBuilderRejectsInvalidWeaponRequest() public view {
        try this.directInvalidWeapon() returns (Ticcmd memory) {
            revert("invalid direct weapon accepted");
        } catch (bytes memory reason) {
            require(
                keccak256(reason)
                    == keccak256(abi.encodeWithSelector(G_Game.InvalidWeaponRequest.selector, uint8(10)))
            );
        }
    }

    function directInvalidWeapon() external pure returns (Ticcmd memory) {
        GameInputState memory state;
        KeyboardInput memory keys;
        keys.weaponRequest = 10;
        return G_Game.G_BuildTiccmd(state, keys);
    }
}
