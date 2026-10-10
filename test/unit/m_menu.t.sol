// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Menu, MenuState} from "../../src/doom/m_menu.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
import {DoomMenu} from "../../src/evm/DoomMenu.sol";
interface MenuVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
}
contract MenuTest {
    MenuVm constant vm = MenuVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    MenuState private saved;
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

    function be32(bytes memory data, uint256 at) private pure returns (int32 n) {
        uint32 value;
        for (uint256 i; i < 4; ++i) value = (value << 8) | uint8(data[at+i]);
        return int32(value);
    }
    function respond(int32 kind, int32 key) external returns (MenuState memory m, bool consumed) {
        m = saved;
        consumed = M_Menu.M_Responder(m, kind, key);
        M_Menu.M_Ticker(m);
        saved = m;
    }
    function testOriginalResponderNativeStateAndStorage() public {
        MenuState memory m;
        M_Menu.M_Init(m, false);
        saved = m;
        bytes memory events = hex"001b011b000d000d00af00af00ad00ac00ae00680068007f007f001b001b000d000d006e000d000d006e001b001b000d000d006e000d0079";
        bytes memory expected = vm.readFileBinary("test/fixtures/evm_menu/responder.bin");
        for (uint256 i; i < events.length / 2; ++i) {
            bool consumed;
            (m, consumed) = this.respond(int32(uint32(uint8(events[i*2]))), int32(uint32(uint8(events[i*2+1]))));
            int32[13] memory actual = [consumed ? int32(1) : int32(0),m.menuactive ? int32(1) : int32(0),
                int32(uint32(m.currentMenu)),m.itemOn,m.whichSkull,m.skullAnimCounter,m.lastOn[0],m.lastOn[1],m.lastOn[2],
                m.messageToPrint ? int32(1) : int32(0),m.startRequested ? m.selectedSkill : int32(-1),
                m.startRequested ? int32(1) : int32(-1),m.startRequested ? m.selectedMap : int32(-1)];
            for (uint256 j; j < 13; ++j) require(actual[j] == be32(expected,i*52+j*4), "original responder field");
        }
    }
    function testMenuOwnsUnknownKeyupsAndWholeStartupPacket() public pure {
        MenuState memory m;
        M_Menu.M_Init(m, true);
        M_Menu.M_StartControlPanel(m);
        require(DoomMenu.respond(m, hex"006901690031019d", true), "menu intercepts letters, weapons and releases");
        require(m.currentMenu == 0 && !m.startRequested, "unrecognized menu input changes no selection");
        DoomMenu.respond(m, hex"00af000d0039000d000d0077009d", true);
        require(m.startRequested && m.selectedMap == 9 && m.selectedSkill == 2, "E1M9 new-game request before trailing gameplay input");
        require(!m.menuactive, "new-game closes menu");
    }
    function testEscapeBackspaceAndOriginalHotkeyCycling() public pure {
        MenuState memory m;
        M_Menu.M_Init(m, true);
        M_Menu.M_StartControlPanel(m);
        M_Menu.M_Responder(m,0,13); M_Menu.M_Responder(m,0,13);
        require(m.currentMenu == 2 && m.itemOn == 2, "original hurtme default");
        M_Menu.M_Responder(m,0,104); require(m.itemOn == 1, "h wraps to rough");
        M_Menu.M_Responder(m,0,104); require(m.itemOn == 2, "h cycles hurtme");
        M_Menu.M_Responder(m,0,127); require(m.currentMenu == 1, "original skill previous episode");
        M_Menu.M_Responder(m,0,27); require(!m.menuactive, "original Escape closes all menus");
        M_Menu.M_Responder(m,0,27); require(m.menuactive && m.currentMenu == 0, "original Escape reopens main");
        M_Menu.M_Responder(m,0,173); require(m.itemOn == 1, "up wraps to select level");
        M_Menu.M_Responder(m,0,13); M_Menu.M_Responder(m,0,173); M_Menu.M_Responder(m,0,13);
        require(m.selectedMap == 9 && m.currentMenu == 2, "nine-map wrap and skill screen");
        M_Menu.M_Responder(m,0,127); require(m.currentMenu == 3 && m.itemOn == 8, "extension remembers selected level");
    }
}
