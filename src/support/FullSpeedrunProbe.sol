// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;
import {IFrameProtocol} from "../evm/FrameProtocol.sol";
import {UltimateWadResources} from "./UltimateWadResources.sol";
import {UltimateStartup} from "./UltimateStartup.sol";
import {DoomGame} from "../evm/DoomGame.sol";
import {DoomUI, UIState} from "../evm/DoomUI.sol";
import {GameState, GameContext} from "../doom/p_game_state.sol";
import {Ticcmd} from "../doom/d_ticcmd.sol";
import {G_Game, GameflowState, GameflowHooks} from "../doom/g_game.sol";
import {WI_Stuff} from "../doom/wi_stuff.sol";
import {WiState, WiInput, WiStart, WiGraphics} from "../doom/wi_stuff_types.sol";
import {F_Finale, FinaleState} from "../doom/f_finale.sol";
import {F_Wipe, WipeState} from "../doom/f_wipe.sol";
import {VideoState} from "../doom/v_video_types.sol";
import {V_Video} from "../doom/v_video.sol";
import {R_Data} from "../doom/r_data.sol";
import {EpisodeStartupSnapshot as Snapshot} from "./EpisodeStartupSnapshot.sol";

/// @notice Separate presentation consumer. Never accepts gameplay state or pixels from a host.
/// @dev Canonical gameplay keeps the historical no-UI miscellaneous RNG counter;
/// presentation retains the native ST/WI/wipe miscellaneous stream separately.
contract FullSpeedrunProbe is UltimateWadResources, IFrameProtocol {
    address public immutable driver=msg.sender;
    bool public initialized;
    GameState private saved;
    UIState private ui;
    WiState private wi;
    WiInput private wiInput;
    FinaleState private finale;
    GameflowState private flow;
    WipeState private wipe;
    bytes private screen;
    uint32 private miscRndindex;
    int32 private displayedState=3; // original wipegamestate initial GS_DEMOSCREEN
    uint32 public demoTics;
    uint64 public frameId;
    uint32 public gameplayFrames;
    uint32 public menuFrames;
    uint32 public wipeFrames;
    uint32 public intermissionFrames;
    uint32 public finaleFrames;
    bool public postExit;
    bool public wipeActive;
    error InvalidReplay();
    event Observation(uint32 tic,bytes state);
    event FramePalette(uint64 indexed frameId,int32 bank,bytes rgb);
    event Presentation(uint64 indexed frameId,uint8 kind,uint32 demoTic,uint32 gameplayTic,
        uint32 rng,int32 state,int32 stage,int32 count,bytes stats);
    constructor(address[] memory chunks,bytes memory directory) UltimateWadResources(chunks,directory) {}
    modifier owner() {if(msg.sender!=driver || !initialized)revert InvalidReplay();_;}
    function initializeMap(uint8 profile,int32 map,int32 skill,bool nomonsters) external {
        if(msg.sender!=driver || initialized || profile!=3)revert InvalidReplay();
        (GameContext memory c,)=UltimateStartup.initialize(_resourceView(),1,map,skill,nomonsters,true);
        c.state.nativeZone.canonicalPointerHighBytes=true;
        c.state.nativeZone.experimentalVirtualPointers=true;
        UIState memory u; DoomUI.initialize(u,c,false); ui=u; saved=c.state;
        GameflowState memory f;f.initialized=true;f.viewactive=true;flow=f;
        initialized=true;
        emit Observation(0,Snapshot.observe(c.state));
    }
    function command(bytes calldata raw) private pure returns(Ticcmd memory cmd) {
        if(raw.length!=4)revert InvalidReplay();
        cmd.forwardmove=int8(uint8(raw[0]));cmd.sidemove=int8(uint8(raw[1]));
        cmd.angleturn=int16(uint16(uint8(raw[2]))<<8);cmd.buttons=uint8(raw[3]);
    }
    function advance(bytes calldata raw) external owner {
        if(wipeActive || postExit || saved.gameaction!=0)revert InvalidReplay();
        GameState memory s=saved;GameContext memory c=DoomGame.load(_resourceView(),s);
        DoomGame.tick(c,command(raw));
        UIState memory u=ui;uint32 canonicalRnd=c.state.rndindex;
        c.state.rndindex=miscRndindex;DoomUI.tick(u,c);miscRndindex=c.state.rndindex;
        c.state.rndindex=canonicalRnd;ui=u;saved=c.state;++demoTics;
        emit Observation(uint32(c.state.gametic),Snapshot.observe(c.state));
    }
    function publish(bytes memory pixels,uint8 kind,int32 state,int32 stage,int32 count,bytes memory stats) private {
        if(pixels.length!=64000)revert InvalidReplay();
        uint64 id=++frameId;
        emit FramePalette(id,postExit || demoTics==0 ? int32(0) : ui.status.st_palette,ui.status.paletteRGB);
        emit Presentation(id,kind,demoTics,uint32(saved.gametic),miscRndindex,state,stage,count,stats);
        // Frame transport uses nonzero presentation sequence; demo/gameplay tics
        // are separately authoritative in Presentation, including title tic zero.
        if(id>type(uint32).max)revert InvalidReplay();
        emit Frame(id,uint32(id),320,200,pixels);
    }
    function title() external owner {
        if(demoTics!=0 || wipeActive || postExit)revert InvalidReplay();
        UIState memory u=ui;DoomUI.basePalette(u,_resourceView());ui=u;
        VideoState memory v;v.screens[0]=new bytes(64000);
        V_Video.V_DrawPatch(v,0,0,0,R_Data.W_CacheLumpNum(_resourceView(),R_Data.W_GetNumForName(_resourceView(),"TITLEPIC")));
        screen=v.screens[0];++menuFrames;publish(screen,1,3,0,0,"");
    }
    function display(bytes memory target,uint8 kind,int32 state,int32 stage,int32 count,bytes memory stats,bool force) private {
        if(screen.length!=64000)revert InvalidReplay();
        if(force || state!=displayedState) {
            WipeState memory w;w.rndindex=miscRndindex;VideoState memory v;v.screens[0]=screen;
            F_Wipe.wipe_StartScreen(w,v);v.screens[0]=target;F_Wipe.wipe_EndScreen(w,v);
            wipe=w;wipeActive=true;displayedState=state;
            // D_Display publishes its first update from the blocking wipe, not the end image.
            stepWipe();
        } else {
            screen=target;
            if(kind==0)++gameplayFrames;else if(kind==3)++intermissionFrames;else if(kind==4)++finaleFrames;
            publish(target,kind,state,stage,count,stats);
        }
    }
    function stepWipe() public owner {
        if(!wipeActive)revert InvalidReplay();
        WipeState memory w=wipe;VideoState memory v;
        bool done=F_Wipe.wipe_ScreenWipe(w,v,1);wipe=w;screen=v.screens[0];
        miscRndindex=w.rndindex;wipeActive=!done;++wipeFrames;
        publish(screen,2,displayedState,0,0,"");
    }
    function capture(uint32 tic) external owner {
        if(wipeActive || postExit || saved.gametic!=tic || tic==0)revert InvalidReplay();
        GameState memory s=saved;GameContext memory c=DoomGame.load(_resourceView(),s);
        c.state.renderFramebuffer=screen;
        UIState memory u=ui;DoomUI.erase(u);DoomUI.drawStatus(u,c);
        bytes memory pixels=DoomGame.render(c,10);DoomUI.drawHUD(u,c.resources.source,pixels);ui=u;
        // Observer insertion point: all generated provenance is emitted here.
        display(pixels,0,0,0,0,"",false);
    }
    function wiStart(GameContext memory c,GameflowState memory f) private view {
        WiState memory w=wi;WiInput memory p;
        p.gamemode=c.state.gamemode;p.playeringame=c.state.playeringame;p.rndindex=miscRndindex;
        for(uint256 i;i<4;++i) {p.attackdown[i]=c.state.players[i].attackdown;p.usedown[i]=c.state.players[i].usedown;}
        WiStart memory start=abi.decode(abi.encode(f.wminfo),(WiStart));WiGraphics memory a;VideoState memory v;
        v.screens[1]=new bytes(64000);WI_Stuff.WI_Start(w,start,p,a,v,c.resources.source);
        // Memory callbacks cannot write storage: carry their independent contexts through adapterData.
        c.adapterData=abi.encode(w,p);
        f.wminfo.maxkills=start.maxkills;f.wminfo.maxitems=start.maxitems;f.wminfo.maxsecret=start.maxsecret;
    }
    function amStop(GameContext memory,GameflowState memory) private pure {revert InvalidReplay();}
    function presentationTick(bytes calldata raw,bool original) external owner {
        if(wipeActive || (!original && !postExit))revert InvalidReplay();
        // Post-exit WI/finale use only their persistent contexts and immutable
        // graphics. Avoid reconstructing unused gameplay definitions/world.
        GameContext memory c;c.resources.source=_resourceView();
        GameflowState memory f=flow;WiState memory w=wi;WiInput memory p=wiInput;FinaleState memory a=finale;
        if(!postExit) {
            c.state=saved;
            if(c.state.gameaction!=6)revert InvalidReplay(); // only an authoritative genuine exit
            GameflowHooks memory h;h.intermissionStart=wiStart;h.automapStop=amStop;
            G_Game.G_DoCompleted(c,f,h);
            if(c.state.gameaction==7)F_Finale.F_StartFinale(c,f,a);
            else {
                (w,p)=abi.decode(c.adapterData,(WiState,WiInput));
                miscRndindex=p.rndindex; // original WI_Start animation initialization
            }
            postExit=true;
            UIState memory u=ui;DoomUI.basePalette(u,c.resources.source);ui=u;
        } else {
            c.state.gamestate=saved.gamemap==8?int32(2):int32(1);
            c.state.gameaction=0;
            c.state.gamemode=saved.gamemode;
        }
        Ticcmd memory cmd=command(raw);
        if(original)++demoTics;
        else if(cmd.forwardmove!=0 || cmd.sidemove!=0 || cmd.angleturn!=0 || cmd.buttons!=0)revert InvalidReplay();
        int32 stage;int32 count;bool force;
        if(c.state.gamestate==1) {
            if(w.worldDoneRequested)revert InvalidReplay();
            p.buttons[0]=cmd.buttons;p.rndindex=miscRndindex;WI_Stuff.WI_Ticker(w,p);miscRndindex=p.rndindex;
            stage=w.sp_state;count=w.bcnt;
            if(w.worldDoneRequested)G_Game.G_WorldDone(c.state,f);
        } else if(c.state.gamestate==2) {
            F_Finale.F_Ticker(a,f);stage=a.finalestage;count=a.finalecount;
            force=f.wipegamestate==-1;f.wipegamestate=c.state.gamestate;
        } else revert InvalidReplay();
        wi=w;wiInput=p;finale=a;flow=f;
        VideoState memory v;v.screens[0]=screen;
        if(c.state.gamestate==1 && !w.worldDoneRequested) {
            WiGraphics memory assets;v.screens[1]=new bytes(64000);
            WI_Stuff.WI_loadData(assets,v,c.resources.source);WI_Stuff.WI_Drawer(w,assets,v);wi=w;
        } else if(c.state.gamestate==2) F_Finale.F_Drawer(a,c.resources.source,v,c.state.gamemode);
        // Canonical saved gameplay never advances or changes after exit. Presentation copy only.
        display(v.screens[0],c.state.gamestate==1?3:4,c.state.gamestate,stage,count,abi.encode(w.wbs),force);
    }
    function presentationState() external view returns(bytes memory) {return abi.encode(wi,wiInput,finale,flow,miscRndindex,wipeActive);}
    function snapshot() external view returns(bytes memory) {GameState memory s=saved;return Snapshot.observe(s);}
    function savedDigest() external view returns(bytes32) {return sha256(abi.encode(saved));}
    function presentationDigest() external view returns(bytes32) {return sha256(abi.encode(ui,wi,wiInput,finale,flow,wipe,screen,miscRndindex,displayedState,demoTics,frameId));}
}
