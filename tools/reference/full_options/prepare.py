#!/usr/bin/env python3
"""Generate an isolated cross-feature test consumer; never edit production sources.

The original FullSpeedrunProbe stays unchanged. This diagnostic copy composes
the accepted Options responder and the recorder's display callbacks. It is not
a browser release or a new recording pipeline. The finale entry is a fixture,
not a claimed genuine E1M8 completion.
"""
import difflib
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'artifacts/local/full-options-main/observer'
assert not OUT.exists(), 'Use a fresh owned output directory'
shutil.copytree(ROOT / 'src', OUT / 'src')
p = OUT / 'src/support/FullSpeedrunProbe.sol'
original = p.read_text()
s = original

def replace(before, after):
    global s
    assert s.count(before) == 1, before
    s = s.replace(before, after)

replace('contract FullSpeedrunProbe is', '''import {M_Menu, MenuState} from "../doom/m_menu.sol";
import {DoomMenu} from "../evm/DoomMenu.sol";
contract FullSpeedrunProbe is''')
replace('UIState private ui;', 'UIState private ui;\n    MenuState private testMenu;\n    bool private testFinale;')
replace('        initialized=true;', '''        MenuState memory m; M_Menu.M_Init(m,true); testMenu=m;
        initialized=true;''')
replace('if(wipeActive || postExit || saved.gameaction!=0)',
        'if(wipeActive || postExit || testMenu.menuactive || saved.gameaction!=0)')
replace('DoomGame.render(c,10)', 'DoomGame.render(c,u.fullscreen ? 11 : 10)')
replace('function presentationState()', '''/// @dev Diagnostic-only composition of accepted production Options hooks.
    function optionEvents(bytes calldata events) external owner {
        if(wipeActive || postExit || demoTics==0)revert InvalidReplay();
        MenuState memory m=testMenu;int32 old=m.screenSize;
        if(!DoomMenu.respond(m,events,true) || m.startRequested || m.endRequested)revert InvalidReplay();
        UIState memory u=ui;u.hideMessages=!m.showMessages;u.fullscreen=m.screenSize==8;
        if(old!=m.screenSize)u.refresh=true;
        if(m.messagesChanged)revert InvalidReplay(); // Messages covered on production adapters.
        bytes memory pixels=screen;
        if(u.refresh){
            GameState memory state=saved;GameContext memory c=DoomGame.load(_resourceView(),state);
            c.state.renderFramebuffer=screen;DoomUI.erase(u);DoomUI.drawStatus(u,c);
            pixels=DoomGame.render(c,u.fullscreen ? 11 : 10);DoomUI.drawHUD(u,c.resources.source,pixels);
        }
        screen=pixels;ui=u;testMenu=m; // Preserve base before original menu overlay.
        M_Menu.M_Drawer(m,_resourceView(),pixels);
        ++menuFrames;publish(pixels,1,0,int32(uint32(m.currentMenu)),m.screenSize,"");
    }
    function testOptionsStatus() external view returns(bool,int32,bool){
        return(testMenu.menuactive,testMenu.screenSize+3,testMenu.showMessages);
    }
    /// @dev Fixture-only F_StartFinale entry; never represents a real level exit.
    function beginFinaleFixture() external owner {
        if(saved.gamemap!=8 || demoTics!=0 || postExit || wipeActive)revert InvalidReplay();
        GameContext memory c;c.state=saved;GameflowState memory f=flow;FinaleState memory a;
        F_Finale.F_StartFinale(c,f,a);finale=a;flow=f;postExit=true;testFinale=true;
        UIState memory u=ui;DoomUI.basePalette(u,_resourceView());ui=u;
    }
    /// @dev Sample the original UI clock without rendering every intermediate text frame.
    function finaleClockFixture(uint32 ticks) external owner {
        if(!testFinale || wipeActive || ticks==0 || ticks>2000)revert InvalidReplay();
        FinaleState memory a=finale;GameflowState memory f=flow;
        for(uint32 i;i<ticks;++i){F_Finale.F_Ticker(a,f);if(f.wipegamestate==-1)revert InvalidReplay();}
        finale=a;flow=f;
    }
    function presentationState()''')
p.write_text(s)
patch=''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),
              fromfile='src/support/FullSpeedrunProbe.sol',tofile=str(p.relative_to(ROOT))))
(OUT/'test-consumer.patch').write_text(patch)
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest={'scope':__doc__,'originalProbeSha256':sha(original.encode()),
          'testConsumerSha256':sha(s.encode()),'patchSha256':sha(patch.encode()),
          'sources':{str(x.relative_to(ROOT)):sha(x.read_bytes()) for x in (OUT/'src').rglob('*.sol')}}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(p)
