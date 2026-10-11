// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {F_Finale, FinaleState} from "../../src/doom/f_finale.sol";
import {GameContext} from "../../src/doom/p_game_state.sol";
import {GameflowState} from "../../src/doom/g_game.sol";
import {VideoState} from "../../src/doom/v_video_types.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {ResourceStore} from "../../src/evm/ResourceStore.sol";

interface FinaleVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function toString(uint256) external pure returns (string memory);
}

contract Doom2CommercialFinaleTest {
    FinaleVm constant vm = FinaleVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function source() private returns (ResourceView memory r) {
        bytes memory blob = vm.readFileBinary("artifacts/local/wad/doom2-ui/finale/resources.bin");
        bytes memory dir = vm.readFileBinary("artifacts/local/wad/doom2-ui/finale/directory.bin");
        r.byteLength = uint32(blob.length);
        r.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 size = blob.length - i * 16384;
            if (size > 16384) size = 16384;
            bytes memory b = new bytes(size);
            for (uint256 j; j < size; ++j) {
                b[j] = blob[i * 16384 + j];
            }
            r.chunks[i] = address(new ResourceStore(b));
        }
        r.lumps = new LumpDescriptor[](dir.length / 16);
        for (uint256 i; i < r.lumps.length; ++i) {
            bytes8 name;
            uint256 p = i * 16;
            assembly ("memory-safe") { name := mload(add(add(dir, 32), p)) }
            r.lumps[i] = LumpDescriptor(name, le32(dir, p + 8), le32(dir, p + 12));
        }
    }

    function le32(bytes memory b, uint256 p) private pure returns (uint32) {
        return uint32(uint8(b[p])) | uint32(uint8(b[p + 1])) << 8 | uint32(uint8(b[p + 2])) << 16
            | uint32(uint8(b[p + 3])) << 24;
    }

    function profile(int32 map, uint256 base) private {
        ResourceView memory r = source();
        GameContext memory c;
        GameflowState memory f;
        FinaleState memory s;
        VideoState memory v;
        c.state.gameepisode = 1;
        c.state.gamemap = map;
        c.state.gamemode = 2;
        c.state.gameaction = 7;
        f.viewactive = true;
        f.automapactive = true;
        v.screens[0] = new bytes(64000);
        F_Finale.F_StartFinale(c, f, s);
        int32[7] memory t = [int32(0), 1, 10, 13, 100, 1000, 2000];
        int32 tic;
        for (uint256 i; i < 7; ++i) {
            while (tic < t[i]) {
                F_Finale.F_Ticker(c, s, f);
                ++tic;
            }
            F_Finale.F_Drawer(s, r, v, 2);
            bytes memory actual = abi.encodePacked(
                s.finalestage,
                s.finalecount,
                c.state.gameaction,
                c.state.gamestate,
                f.viewactive ? int32(1) : int32(0),
                f.automapactive ? int32(1) : int32(0),
                f.wipegamestate,
                v.screens[0]
            );
            require(
                sha256(actual)
                    == sha256(
                        vm.readFileBinary(
                            string.concat("artifacts/local/wad/doom2-ui/finale/", vm.toString(base + i), ".bin")
                        )
                    ),
                "native state and all 64000 finale pixels"
            );
            require(!F_Finale.F_Responder(s), "E1 has no cast input or skip");
        }
        require(
            c.state.gamestate == 2 && c.state.gameepisode == 1 && c.state.gameaction == 0,
            "no Episode Two continuation"
        );
    }

    function testOriginalCommercialMap6TextPixels() public {profile(6,0);}
    function testOriginalCommercialMap11TextPixels() public {profile(11,7);}
    function testOriginalCommercialMap20TextPixels() public {profile(20,14);}
    function testOriginalCommercialMap30TextPixels() public {profile(30,21);}
    function testOriginalCommercialMap15TextPixels() public {profile(15,28);}
    function testOriginalCommercialMap31TextPixels() public {profile(31,35);}
    function testCommercialButtonSkipUsesOriginalCounterBoundary() public pure {
        GameContext memory c;GameflowState memory f;FinaleState memory s;
        c.state.gameepisode=1;c.state.gamemode=2;c.state.gamemap=6;
        F_Finale.F_StartFinale(c,f,s);s.finalecount=50;c.state.players[0].cmd.buttons=1;
        F_Finale.F_Ticker(c,s,f);require(c.state.gameaction==0&&s.finalecount==51,"original >50 boundary");
        F_Finale.F_Ticker(c,s,f);require(c.state.gameaction==8&&s.finalecount==52,"original continuation action");
    }
}
