// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {M_Menu,MenuState} from "../../src/doom/m_menu.sol";
import {DoomMenu} from "../../src/evm/DoomMenu.sol";
contract Doom2MenuTest {
    function testCommercialNewGameSkipsEpisodeAndReturnsToMain() public pure {
        MenuState memory m; M_Menu.M_Init(m,true);m.commercial=true;M_Menu.M_StartControlPanel(m);
        DoomMenu.respond(m,hex"000d",false);
        require(m.currentMenu==2&&m.itemOn==2&&m.selectedMap==1,"commercial New Game goes directly to hurtme skill");
        DoomMenu.respond(m,hex"007f",false);require(m.currentMenu==0,"commercial skill previous is main");
        DoomMenu.respond(m,hex"001b",true);require(!m.menuactive,"Escape resumes");
        DoomMenu.respond(m,hex"001b",true);require(m.menuactive&&m.currentMenu==0,"Escape reopens");
    }
    function testAll32MapsReuseOriginalSkillRequests() public pure {
        for(int32 map=1;map<=32;++map){
            MenuState memory m;M_Menu.M_Init(m,true);m.commercial=true;M_Menu.M_StartControlPanel(m);
            DoomMenu.respond(m,hex"0073000d",true);require(m.currentMenu==3,"select level");
            for(int32 i=1;i<map;++i)M_Menu.M_Responder(m,0,175);
            DoomMenu.respond(m,hex"000d",true);require(m.currentMenu==2&&m.selectedMap==map,"32-map selection");
            DoomMenu.respond(m,hex"000d",true);require(m.startRequested&&m.selectedSkill==2&&!m.menuactive,"ordinary deferred game request");
        }
    }
    function testFiveSkillsAndNightmareConfirmationPreserveCommercialMap() public pure {
        for(int32 skill=0;skill<5;++skill){
            MenuState memory m;M_Menu.M_Init(m,true);m.commercial=true;M_Menu.M_StartControlPanel(m);
            DoomMenu.respond(m,hex"0073000d00ad000d",true);require(m.selectedMap==32,"map wrap");
            m.itemOn=skill;DoomMenu.respond(m,hex"000d",true);
            if(skill==4){require(m.messageToPrint&&!m.startRequested,"original Nightmare prompt");DoomMenu.respond(m,hex"0079",true);}
            require(m.startRequested&&m.selectedSkill==skill&&m.selectedMap==32,"five skills retain selected map");
        }
    }
}
