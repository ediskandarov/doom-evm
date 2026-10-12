// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Menu, MenuState} from "../../src/doom/m_menu.sol";
import {DoomMenu} from "../../src/evm/DoomMenu.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";

interface SaveMenuVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
}

contract SaveMenuTest {
    SaveMenuVm constant vm = SaveMenuVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function source() private returns (ResourceView memory r) {
        bytes memory blob = vm.readFileBinary("test/fixtures/save_menu/resources.bin");
        bytes memory dir = vm.readFileBinary("test/fixtures/save_menu/directory.bin");
        r.byteLength = uint32(blob.length);
        r.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 n = blob.length - i * 16384;
            if (n > 16384) n = 16384;
            bytes memory code = new bytes(n + 1);
            for (uint256 j; j < n; ++j) {
                code[j + 1] = blob[i * 16384 + j];
            }
            r.chunks[i] = address(uint160(0x680000 + i));
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
        return uint32(uint8(b[p])) | uint32(uint8(b[p + 1])) << 8 | uint32(uint8(b[p + 2])) << 16
            | uint32(uint8(b[p + 3])) << 24;
    }

    function setup(MenuState memory m, ResourceView memory r) private view {
        M_Menu.M_Init(m, true);
        m.savesEnabled = true;
        m.usergame = true;
        m.canSave = true;
        M_Menu.M_LoadSaveFont(m, r);
        for (uint8 i; i < 6; ++i) {
            M_Menu.M_ReadSaveStrings(
                m,
                i,
                i == 0 ? bytes("MOVEMENT") : i == 2 ? bytes("COMBAT") : bytes("PROJECTILE"),
                i == 0 || i == 2 || i == 5,
                1
            );
        }
        m.menuactive = true;
    }

    function testOriginalSixSlotGraphicsAllSkullsAndEntry() public {
        ResourceView memory r = source();
        MenuState memory m;
        setup(m, r);
        for (uint8 menu; menu < 2; ++menu) {
            for (uint8 slot; slot < 6; ++slot) {
                for (uint8 skull; skull < 2; ++skull) {
                    m.currentMenu = menu + 5;
                    m.itemOn = int32(uint32(slot));
                    m.whichSkull = int32(uint32(skull));
                    bytes memory pixels = M_Menu.title(r);
                    M_Menu.M_Drawer(m, r, pixels);
                    string memory name = string(
                        abi.encodePacked(
                            "test/fixtures/save_menu/slots-",
                            bytes1(menu + 48),
                            "-",
                            bytes1(slot + 48),
                            "-",
                            bytes1(skull + 48),
                            ".bin"
                        )
                    );
                    require(sha256(pixels) == sha256(vm.readFileBinary(name)), "original slot pixels");
                }
            }
        }
        m.currentMenu = 6;
        m.itemOn = 1;
        m.whichSkull = 0;
        M_Menu.M_SaveSelect(m);
        M_Menu.M_Responder(m, 0, 120);
        bytes memory pixels = M_Menu.title(r);
        M_Menu.M_Drawer(m, r, pixels);
        require(
            sha256(pixels) == sha256(vm.readFileBinary("test/fixtures/save_menu/entry.bin")),
            "original entry cursor"
        );
    }

    function testSaveEditingCancelOverwriteAndWholePacketIsolation() public {
        ResourceView memory r = source();
        MenuState memory m;
        setup(m, r);
        m.menuactive = false;
        DoomMenu.respond(m, hex"00bc", true);
        require(m.currentMenu == 6, "F2 save");
        m.itemOn = 1;
        DoomMenu.respond(m, hex"000d006d006f00760065007f0065001b", true);
        require(
            !m.saveStringEnter && m.saveAction == 0
                && keccak256(m.savegamestrings[1]) == keccak256(bytes("EMPTY SLOT")),
            "edit cancel"
        );
        DoomMenu.respond(m, hex"000d0078000d0077", true);
        require(
            m.saveAction == 1 && m.saveSlot == 1 && !m.menuactive
                && keccak256(m.saveDescription) == keccak256(bytes("X")),
            "save request"
        );
        m.saveAction = 0;
        m.menuactive = true;
        m.currentMenu = 6;
        m.itemOn = 2;
        M_Menu.M_SaveSelect(m);
        require(keccak256(m.saveDescription) == keccak256(bytes("COMBAT")), "overwrite description");
        DoomMenu.respond(m, hex"000d", true);
        require(m.saveAction == 1 && m.saveRevisions[m.saveSlot] == 1, "overwrite revision");
    }

    function testLoadSkipsEmptyAndAllEmptyMenuTerminates() public {
        ResourceView memory r = source();
        MenuState memory m;
        setup(m, r);
        m.menuactive = false;
        DoomMenu.respond(m, hex"00bd00af", true);
        require(m.currentMenu == 5 && m.itemOn == 2, "F3 skips empty");
        DoomMenu.respond(m, hex"000d0077", true);
        require(m.saveAction == 2 && m.saveSlot == 2 && !m.menuactive, "load request isolation");
        m.saveAction = 0;
        m.menuactive = true;
        m.currentMenu = 5;
        for (uint8 i; i < 6; ++i) {
            m.saveOccupied[i] = false;
        }
        DoomMenu.respond(m, hex"00af00ad000d", true);
        require(m.saveAction == 0, "empty load disabled");
    }
}
