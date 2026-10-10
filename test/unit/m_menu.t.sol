// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Menu, MenuState} from "../../src/doom/m_menu.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
interface MenuVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
}
contract MenuTest {
    MenuVm constant vm = MenuVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function source() internal returns (ResourceView memory r) {
        bytes memory blob = vm.readFileBinary("test/fixtures/evm_menu/resources.bin");
        bytes memory dir = vm.readFileBinary("test/fixtures/evm_menu/directory.bin");
        r.byteLength = uint32(blob.length);
        r.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 n = blob.length - i * 16384;
            if (n > 16384) n = 16384;
            bytes memory code = new bytes(n + 1);
            for (uint256 j; j < n; ++j) code[j + 1] = blob[i * 16384 + j];
            r.chunks[i] = address(uint160(0x650000 + i));
            vm.etch(r.chunks[i], code);
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
        return uint32(uint8(b[p])) | uint32(uint8(b[p+1])) << 8 | uint32(uint8(b[p+2])) << 16 | uint32(uint8(b[p+3])) << 24;
    }
    function compare(MenuState memory m, ResourceView memory r, string memory name) private view {
        bytes memory pixels = M_Menu.title(r);
        M_Menu.M_Drawer(m, r, pixels);
        require(sha256(pixels) == sha256(vm.readFileBinary(string.concat("test/fixtures/evm_menu/", name, ".bin"))), name);
    }
    function testOriginalMenuNativePixelsAndSkullAnimation() public {
        ResourceView memory r = source();
        MenuState memory m;
        M_Menu.M_Init(m, false);
        m.menuactive = true;
        compare(m, r, "main-skull0");
        for (uint256 i; i < 10; ++i) M_Menu.M_Ticker(m);
        require(m.whichSkull == 1 && m.skullAnimCounter == 8, "original ten-tic initial skull");
        compare(m, r, "main-skull1");
        for (uint256 i; i < 8; ++i) M_Menu.M_Ticker(m);
        require(m.whichSkull == 0, "original eight-tic skull");
        m.currentMenu = 1;
        compare(m, r, "episode");
        m.currentMenu = 2;
        for (int32 i; i < 5; ++i) {
            m.itemOn = i;
            compare(m, r, string(abi.encodePacked("skill-", bytes1(uint8(uint32(i) + 48)))));
        }
        m.messageToPrint = true;
        compare(m, r, "nightmare");
    }
    function testExtendedLevelScreenBoundsAndUniqueSelection() public {
        ResourceView memory r = source();
        MenuState memory m;
        M_Menu.M_Init(m, true);
        m.menuactive = true;
        m.currentMenu = 3;
        bytes32 prior;
        for (int32 i; i < 9; ++i) {
            m.itemOn = i;
            bytes memory pixels = M_Menu.title(r);
            M_Menu.M_Drawer(m, r, pixels);
            bytes32 hash = sha256(pixels);
            require(pixels.length == 64000 && hash != prior, "distinct bounded EVM skull selection");
            prior = hash;
        }
    }
}
