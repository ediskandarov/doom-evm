// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Menu, MenuState} from "../../src/doom/m_menu.sol";
import {DoomMenu} from "../../src/evm/DoomMenu.sol";
import {HU_Stuff, HudState} from "../../src/doom/hu_stuff.sol";
import {Player} from "../../src/doom/p_game_state.sol";
import {ResourceView} from "../../src/doom/r_data_types.sol";
import {LumpDescriptor} from "../../src/evm/ResourceTypes.sol";
interface OptionsVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function etch(address, bytes calldata) external;
}
contract OptionsMenuTest {
    OptionsVm constant vm = OptionsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function source() private returns (ResourceView memory r) {
        bytes memory blob = vm.readFileBinary("test/fixtures/options_menu/resources.bin");
        bytes memory dir = vm.readFileBinary("test/fixtures/options_menu/directory.bin");
        r.byteLength = uint32(blob.length);
        r.chunks = new address[]((blob.length + 16383) / 16384);
        for (uint256 i; i < r.chunks.length; ++i) {
            uint256 n = blob.length - i * 16384;
            if (n > 16384) n = 16384;
            bytes memory code = new bytes(n + 1);
            for (uint256 j; j < n; ++j) code[j + 1] = blob[i * 16384 + j];
            r.chunks[i] = address(uint160(0x660000 + i)); vm.etch(r.chunks[i], code);
        }
        r.lumps = new LumpDescriptor[](dir.length / 16);
        for (uint256 i; i < r.lumps.length; ++i) {
            bytes8 name; uint256 p = i * 16;
            assembly ("memory-safe") { name := mload(add(add(dir, 32), p)) }
            r.lumps[i] = LumpDescriptor(name, le32(dir,p+8), le32(dir,p+12));
        }
    }
    function le32(bytes memory b,uint256 p) private pure returns(uint32) {
        return uint32(uint8(b[p])) | uint32(uint8(b[p+1]))<<8 | uint32(uint8(b[p+2]))<<16 | uint32(uint8(b[p+3]))<<24;
    }
    function be32(bytes memory b,uint256 p) private pure returns(int32) {
        uint32 n; for(uint256 i;i<4;++i)n=(n<<8)|uint8(b[p+i]);return int32(n);
    }
    function testOriginalOptionsPixelsAllThermometerPositionsAndRows() public {
        ResourceView memory r=source();MenuState memory m;M_Menu.M_Init(m,false);m.menuactive=true;m.currentMenu=4;
        bytes memory hashes=vm.readFileBinary("test/fixtures/options_menu/options-hashes.bin");
        for(int32 size;size<9;++size)for(uint32 msg;msg<2;++msg)for(int32 item;item<8;++item){
            m.screenSize=size;m.showMessages=msg!=0;m.itemOn=item;
            bytes memory p=M_Menu.title(r);M_Menu.M_Drawer(m,r,p);
            uint256 at=(uint32(size)*16+msg*8+uint32(item))*32;bytes32 expected;
            assembly ("memory-safe") { expected := mload(add(add(hashes,32),at)) }
            require(sha256(p)==expected,"original options pixels");
        }
        m.messageKind=1;m.messageToPrint=true;bytes memory pixels=M_Menu.title(r);M_Menu.M_Drawer(m,r,pixels);
        require(sha256(pixels)==sha256(vm.readFileBinary("test/fixtures/options_menu/endgame.bin")),"original End Game dialog pixels");
    }
    function testOriginalSupportedOptionsResponderAgainstC() public view {
        MenuState memory m;M_Menu.M_Init(m,false);m.menuactive=true;m.usergame=true;M_Menu.M_Options(m);
        int32[29] memory keys=[int32(109),13,13,115,174,174,172,172,174,13,127,111,13,101,13,119,110,27,111,13,101,13,27,27,111,13,101,13,121];
        bytes memory expected=vm.readFileBinary("test/fixtures/options_menu/options-responder.bin");
        for(uint256 i;i<keys.length;++i){
            bool consumed=M_Menu.M_Responder(m,0,keys[i]);M_Menu.M_Ticker(m);
            int32[11] memory actual=[consumed?int32(1):int32(0),m.menuactive?int32(1):int32(0),int32(uint32(m.currentMenu)),m.itemOn,m.whichSkull,m.skullAnimCounter,m.lastOn[4],m.showMessages?int32(1):int32(0),m.screenSize,m.messageToPrint?int32(1):int32(0),m.endRequested?int32(1):int32(0)];
            for(uint256 j;j<11;++j) require(actual[j]==be32(expected,i*44+j*4),"original supported Options responder");
        }
    }
    function testProductionOptionsSkipUnsupportedRowsAndPersist() public pure {
        MenuState memory m;M_Menu.M_Init(m,true);M_Menu.M_StartControlPanel(m);
        DoomMenu.respond(m,hex"006f000d",true);require(m.currentMenu==4&&m.itemOn==0,"Options main entry");
        DoomMenu.respond(m,hex"00af000d",true);require(!m.showMessages&&m.messagesChanged,"Messages actual setting");
        DoomMenu.respond(m,hex"00af",true);require(m.itemOn==3,"skip unavailable detail");
        DoomMenu.respond(m,hex"00ac00ac",true);require(m.screenSize==7,"unsupported small view clamped");
        DoomMenu.respond(m,hex"00ae00ae000d",true);require(m.screenSize==8,"right and Enter clamp at fullscreen");
        DoomMenu.respond(m,hex"007f000d",true);require(m.currentMenu==4&&m.itemOn==3&&!m.showMessages&&m.screenSize==8,"back and reopen persist");
        DoomMenu.respond(m,hex"00af",true);require(m.itemOn==0,"down wraps after screen size");
        DoomMenu.respond(m,hex"00ad",true);require(m.itemOn==3,"up wraps to screen size");
    }
    function testEndGameTitleGuardCancelConfirmAndInputIsolation() public pure {
        MenuState memory m;M_Menu.M_Init(m,true);M_Menu.M_StartControlPanel(m);
        DoomMenu.respond(m,hex"006f000d000d",false);require(!m.messageToPrint&&!m.endRequested,"title has no user game");
        DoomMenu.respond(m,hex"000d",true);require(m.messageToPrint&&m.messageKind==1,"End Game confirmation");
        DoomMenu.respond(m,hex"0077",true);require(m.messageToPrint,"confirmation rejects gameplay key");
        DoomMenu.respond(m,hex"006e",true);require(!m.menuactive&&!m.endRequested,"original cancel closes menus");
        DoomMenu.respond(m,hex"001b006f000d0065000d0079009d",true);
        require(m.endRequested&&!m.startRequested&&!m.menuactive,"End Game halts packet before gameplay");
    }
    function testMessagesOffKeepsOriginalGenerationAndForcedNotice() public pure {
        HudState memory h;Player memory p;h.headsupactive=true;h.message.h=1;
        p.message="Picked up a clip.";
        HU_Stuff.HU_Ticker(h,p,false);
        require(!h.message.on&&keccak256(bytes(p.message))==keccak256("Picked up a clip."),"off preserves generated player message");
        p.message="Messages OFF";h.message_dontfuckwithme=true;
        HU_Stuff.HU_Ticker(h,p,false);
        require(h.message.on&&h.message_counter==140&&bytes(p.message).length==0&&h.message_nottobefuckedwith,"forced setting notice visible while off");
        p.message="Picked up a clip.";
        for(uint256 i;i<140;++i)HU_Stuff.HU_Ticker(h,p,false);
        require(!h.message.on&&bytes(p.message).length!=0,"off hides actual pickup after protected notice expires");
        HU_Stuff.HU_Ticker(h,p,true);
        require(h.message.on&&h.message_counter==140&&bytes(p.message).length==0,"on consumes actual pending pickup");
    }
}
