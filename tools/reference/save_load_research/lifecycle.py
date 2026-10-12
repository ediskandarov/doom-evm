#!/usr/bin/env python3
"""Execute full original save/load action lifecycle in authentic native worlds."""
import argparse,importlib.util,json,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
sys.path.insert(0,str(ROOT/'tools/reference/gameplay'));from build import renderer,PUNITS,ref,extract
spec=importlib.util.spec_from_file_location('canonical_save_ui',ROOT/'tools/reference/ui/reference.py')
ui=importlib.util.module_from_spec(spec);spec.loader.exec_module(ui)
FUNCTIONS=['G_PlayerReborn','G_InitPlayer','G_PlayerFinishLevel','G_CheckSpot','G_DoReborn',
 'G_ExitLevel','G_SecretExitLevel','G_DoCompleted','G_WorldDone','G_DoWorldDone',
 'G_DeferedInitNew','G_DoNewGame','G_InitNew','G_DoLoadLevel','G_BuildTiccmd',
 'G_SaveGame','G_LoadGame','G_DoSaveGame','G_DoLoadGame','G_Ticker']
CASES=['rich-direct','queued','paused-queued','time-wrap','nightmare-archive','medium-archive','bad-version','bad-version-queued','reborn-load','dead-save','write-failure']

def verify(case,rows):
    phase=lambda n:next(x for x in reversed(rows) if x['phase']==n)
    if case in ['queued','paused-queued']:
        request=phase('save-request');command=phase('after-save-command-tic');written=phase('before-write');header=phase('file-header')
        assert request['gameaction']==0 and request['sendsave']==1
        assert command['gameaction']==4 and command['sendsave']==0 and written['gametic']==command['gametic']
        assert header['savedLeveltime']==command['leveltime']
        assert phase('after-write-tic')['gametic']==command['gametic']+1
        loaded=phase('after-load');tick=phase('after-load-tic');pending=phase('load-request')
        assert loaded['leveltime']==header['savedLeveltime'] and loaded['gametic']==pending['gametic']
        assert tick['gametic']==pending['gametic']+1 and tick['leveltime']==header['savedLeveltime']+1
        assert tick['cmdForward']==25 and tick['keysUp']==0 and tick['stClock']==1
    elif case=='rich-direct':
        saved=phase('presave');loaded=phase('loaded-direct');current=phase('diverged')
        assert (loaded['health'],loaded['ammo'])==(73,43)
        assert loaded['gametic']==current['gametic'] and loaded['gametic']!=saved['gametic']
        assert loaded['levelstarttic']==current['gametic'] and loaded['leveltime']==saved['leveltime']
        assert loaded['prndindex']!=saved['prndindex'] and loaded['rndindex']==0 and loaded['paused']==0
        assert loaded['floorHeight']==((saved['floorHeight']>>16)<<16) and loaded['sideTextureOffset']==((saved['sideTextureOffset']>>16)<<16)
        assert loaded['attacker']==loaded['playerTarget']==loaded['sectorSoundTarget']==loaded['actorTargets']==0
        assert saved['fireFlickers']>0 and loaded['fireFlickers']==0 and saved['stasisPlats']==1 and loaded['stasisPlats']==0
        assert saved['stasisCeilings']==loaded['stasisCeilings']==1 and loaded['buttonTimer']==0
        assert loaded['stClock']==loaded['hudOn']==loaded['automapactive']==0 and loaded['hudCounter']==current['hudCounter']
        assert loaded['turnheld']==current['turnheld']!=saved['turnheld'] and loaded['playerTracer']==1
        assert loaded['nativeThinkerAllocations']>saved['nativeThinkerAllocations']
        kinds=loaded['thinkerOrder'];assert kinds[:loaded['actors']]==[1]*loaded['actors'] and 1 not in kinds[loaded['actors']:]
    elif case=='time-wrap':assert phase('file-header')['savedLeveltime']==phase('loaded-direct')['leveltime']==5
    elif case in ['nightmare-archive','medium-archive']:
        saved=phase('saved-difficulty');current=phase('current-difficulty');loaded=phase('loaded-difficulty')
        assert loaded['skill']==saved['skill'] and loaded['sargTics']==current['sargTics']!=saved['sargTics']
        assert loaded['projectileSpeed']==current['projectileSpeed']!=saved['projectileSpeed']
    elif case=='bad-version':
        current=phase('diverged');loaded=phase('loaded-direct')
        assert loaded['gameaction']==0 and all(loaded[k]==current[k] for k in ['health','ammo','prndindex','rndindex','gametic','stClock','keysUp'])
        assert sum(x['phase']=='before-init-new' for x in rows)==1
    elif case=='bad-version-queued':
        current=phase('invalid-load-request');loaded=phase('invalid-load-tic')
        assert loaded['gameaction']==0 and loaded['gametic']==current['gametic']+1 and loaded['leveltime']==current['leveltime']+1
        assert sum(x['phase']=='before-init-new' for x in rows)==1
    elif case=='reborn-load':
        assert not any(x['phase']=='before-load' for x in rows)
        assert phase('reborn-load-tic')['health']==100 and phase('reborn-load-tic')['ammo']==50
    elif case=='dead-save':
        assert not any(x['phase']=='before-write' for x in rows)
        assert phase('dead-save-command-tic')['gameaction']==4 and phase('dead-save-rebirth-tic')['health']==100
        assert phase('dead-save-rebirth-tic')['gameaction']==0
    elif case=='write-failure':assert phase('write-failure-return')['playerMessage']=='game saved.' and phase('write-failure-return')['gameaction']==0

def build(out,opt,sanitize):
    ui.build_ui(out,opt,sanitize)
    manifest=json.loads((out/'ui-build-manifest.json').read_text())
    text=(ref.SOURCE/'g_game.c').read_text();prefix=text[:text.index('int G_CmdChecksum')]
    bodies=[];spans=[]
    for name in FUNCTIONS:
        body,span=extract('g_game.c',name);spans.append(span)
        if name in ['G_DoSaveGame','G_DoLoadGame','G_InitNew','G_DoLoadLevel']:
            body=f'#define {name} Original_{name}\n'+body+f'\n#undef {name}\n'
        bodies.append(body)
    constants='\n'.join(re.search(r'int '+n+r'\[[^;]*?\};',text)[0] for n in ['pars','cpars'])
    declarations='\nskill_t d_skill; int d_episode,d_map; char savename[256];\n#define VERSIONSIZE 16\nextern boolean setsizeneeded,secretexit;\n'
    io=[]
    for name in ['M_ReadFile','M_WriteFile']:
        source=(ref.SOURCE/'m_misc.c').read_text();m=re.search(r'\n(?:int|boolean)\s+'+name+r'\s*\([^;{}]*\)\s*\{',source);assert m,name
        start=m.start()+1;end=m.end();depth=1
        while depth:depth+=(source[end]=='{')-(source[end]=='}');end+=1
        body=source[start:end];span={'file':'m_misc.c','function':name,'startLine':source[:start].count('\n')+1,'endLine':source[:end].count('\n')+1,'sha256':ref.sha(body.encode())}
        io.append(body);spans.append(span)
    (out/'canonical-game.c').write_text(prefix+declarations+constants+'\n'+'\n'.join(bodies))
    (out/'canonical-io.c').write_text('#include <fcntl.h>\n#include <unistd.h>\n#include <sys/stat.h>\n#include "doomdef.h"\n#include "z_zone.h"\n#include "i_system.h"\n#ifndef O_BINARY\n#define O_BINARY 0\n#endif\n'+'\n'.join(io))
    host=(out/'ui-host.c').read_text();host=host[:host.index('int main(int argc,char **argv) {')]
    removals=['int consoleplayer=0, displayplayer=0;\n','boolean demoplayback=false;\n','player_t players[MAXPLAYERS];\n',
      'boolean netgame=false, deathmatch=false, paused=false, menuactive=false;\n',
      'boolean playeringame[MAXPLAYERS]={true,false,false,false};\n',
      'boolean respawnmonsters=false, respawnparm=false, fastparm=false, nomonsters=false;\n',
      'boolean precache=false, secretexit=false, automapactive=false;\n',
      'int gametic=0, gameepisode=1, gamemap=1, totalkills=0,totalitems=0,totalsecret=0,bodyqueslot=0;\n',
      'skill_t gameskill=sk_medium;\n','gameaction_t gameaction=ga_nothing;\n','gamestate_t gamestate=GS_LEVEL;\n','wbstartstruct_t wminfo;\n',
      'void AM_Stop(void) { automapactive=false; }\n']
    for s in removals:assert host.count(s)==1,s;host=host.replace(s,'')
    host=host.replace('#include "info.h"','#include "info.h"\nextern boolean secretexit;')
    host=host.replace('static FILE *tracefile;','static FILE *tracefile;\nvoid CanonicalAllocation(void*,int);')
    host=host.replace('void OracleAllocation(void *p,int size) {','void OracleAllocation(void *p,int size) { CanonicalAllocation(p,size);')
    host+='\n'+(HERE/'host.c').read_text().replace('states[S_SARG_RUN1].tics,mobjinfo','(int)states[S_SARG_RUN1].tics,mobjinfo')
    (out/'canonical-host.c').write_text(host)
    archive=(ref.SOURCE/'p_saveg.c').read_text()
    archive,n=re.subn(r'#define PADSAVEP\(\)[^\n]*','#define PADSAVEP() save_p += (8 - ((uintptr_t) save_p & 7)) & 7',archive);assert n==1
    (out/'canonical-save.c').write_text(archive)
    # Reuse declared immutable UI borrowing consistently, including AM/ST_lib.
    for name in ['st_lib.c','am_map.c']:
        source=(ref.SOURCE/name).read_text();source='#define W_CacheLumpName UIWCacheName\n#define W_CacheLumpNum UIWCacheNum\n'+source
        source=source.replace('#include "z_zone.h"','#include "z_zone.h"\n#undef Z_ChangeTag\n#define Z_ChangeTag(p,t) ((void)0)')
        (out/name).write_text(source)
    (out/'m_cheat.c').write_bytes((ref.SOURCE/'m_cheat.c').read_bytes())
    flags=[f.replace('<HARNESS>',str(ROOT/'tools/reference')) for f in manifest['flags']]
    if sanitize and '-fno-sanitize=array-bounds' not in flags:flags+=['-fno-sanitize=array-bounds']
    names=renderer.UNITS+PUNITS+['st_stuff.c','st_lib.c','hu_stuff.c','hu_lib.c','v_video.c','am_map.c','m_cheat.c',
       'canonical-game.c','canonical-io.c','canonical-save.c','canonical-host.c']
    flags+=['-Wno-implicit-int'] # Accept original am_map.c implicit-int C89 declarations.
    command=['clang',*flags,'-ffunction-sections','-fdata-sections','-I'+str(out),'-I'+str(ROOT/'tools/reference/gameplay'),
      *[str(out/n) for n in names],'-Wl,-dead_strip','-o',str(out/'canonical-native')]
    r=subprocess.run(command,text=True,capture_output=True);(out/'canonical-build.log').write_text(r.stdout+r.stderr)
    if r.returncode:raise RuntimeError(r.stderr)
    manifest.update(extractions=spans,canonicalCommand=command,
       canonicalSourceHashes={n:ref.sha((out/n).read_bytes()) for n in names},
       adaptations=manifest['adaptations']+[
        {'scope':'archive layout','reason':'Generated p_saveg.c PADSAVEP uses uintptr_t/align8 for LP64. Algorithms and field writes unchanged; binary compatibility not asserted.'},
        {'scope':'action observation','reason':'Original G_DoSaveGame/G_DoLoadGame/G_InitNew/G_DoLoadLevel bodies mechanically extracted unchanged, symbols macro-renamed; wrappers record entry/exit, then call those original bodies.'},
        {'scope':'host','reason':'Clock is a deterministic I_GetTime boundary; ordinary local file IO uses original M_ReadFile/M_WriteFile; bounded single-player commands fill netcmds, original G_Ticker executes. Audio and excluded demo/intermission/finale paths are inert/abort boundaries.'}])
    (out/'canonical-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return out/'canonical-native',manifest

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--freedoom',type=Path,default=ROOT/'artifacts/local/freedoom/freedoom1.wad')
    ap.add_argument('--ultimate',type=Path,default=ROOT/'artifacts/local/options/DOOM.WAD');ap.add_argument('--doom2',type=Path,default=ROOT/'artifacts/local/options/DOOM2.WAD')
    ap.add_argument('--output',type=Path,default=ROOT/'artifacts/local/save-load-canonical/run1');ap.add_argument('--profiles',default='O0,O2,sanitize');args=ap.parse_args();args.output=args.output.resolve();args.output.mkdir(parents=True,exist_ok=True)
    report={'kind':__doc__,'pass':False,'startedUtc':__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(),
      'baseline':'01b09cdbc31e774b7da9937f3a9c67b3ad3d958b','upstreamCommit':ref.UPSTREAM,'cases':CASES,'profiles':[],
      'sourceHashes':{n:ref.sha((ref.SOURCE/n).read_bytes()) for n in ['g_game.c','p_saveg.c','p_saveg.h','m_menu.c','m_misc.c','p_setup.c','p_spec.c','p_tick.c','p_mobj.c','p_user.c','st_stuff.c','hu_stuff.c','am_map.c']},
      'harnessHashes':{str(p.relative_to(ROOT)):ref.sha(p.read_bytes()) for p in [HERE/'lifecycle.py',HERE/'host.c']}}
    canonical={}
    try:
        for profile in args.profiles.split(','):
            out=args.output/profile;exe,manifest=build(out,'O0' if profile=='O0' else 'O2',profile=='sanitize')
            row={'profile':profile,'manifest':manifest,'games':{}};report['profiles'].append(row)
            for game in ['freedoom','ultimate','doom2']:
                wad=getattr(args,game).resolve();identity=ref.sha(wad.read_bytes())
                assert identity=={'freedoom':'7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d','ultimate':'6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f','doom2':'10d67824b11025ddd9198e8cfc87ca335ee6e2d3e63af4180fa9b8a471893255'}[game]
                results={};row['games'][game]={'wadSha256':identity,'cases':results}
                for case in CASES:
                    dest=out/(game+'-'+case);dest.mkdir();env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0:halt_on_error=1',UBSAN_OPTIONS='halt_on_error=1');env.pop('DOOM_ORACLE_ALLOCATION_FILL',None)
                    r=subprocess.run([str(exe),str(wad),str(dest),game,case],text=True,capture_output=True,env=env);(dest/'run.log').write_text(r.stdout+r.stderr)
                    assert r.returncode==0 and not r.stderr,(profile,game,case,r.returncode,r.stderr)
                    value=json.loads((dest/'observations.json').read_text());verify(case,value)
                    result={'observations':value,'frameHashes':{p.name:ref.sha(p.read_bytes()) for p in sorted(dest.iterdir()) if p.suffix in ['.indexed8','.palette']},'allocatorTimelineSha256':ref.sha((dest/'allocations.tsv').read_bytes()),'allBehaviorAssertionsPassed':True}
                    results[case]=result
                    key=(game,case)
                    if key not in canonical:canonical[key]=result
                    else:assert result==canonical[key],(profile,game,case,'logical lifecycle or framebuffer divergence')
                    print('PASS full original lifecycle',profile,game,case,flush=True)
        report['pass']=True
    except BaseException as e:report['error']=str(e);raise
    finally:
        report['endedUtc']=__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat()
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        published=ROOT/'artifacts/save-load-canonical';published.mkdir(exist_ok=True)
        (published/'native-lifecycle.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
