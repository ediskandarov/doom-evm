#!/usr/bin/env python3
"""Real original-C Episode One startup, world/collision/flow/zone observations."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent / 'gameplay'))
from build import ref, renderer, PUNITS

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

zone = module('episode_zone_reference', HERE.parent/'phase3_zone_lifecycle/reference.py')
gameflow = module('episode_gameflow_reference', HERE.parent/'gameflow/reference.py')

GLOBALS = r'''
#include "doomstat.h"
#include "g_game.h"
#include "p_local.h"
#include "w_wad.h"
#include "r_sky.h"
#include "m_random.h"
#include "s_sound.h"
#include "i_system.h"
extern int starttime;
extern boolean gamekeydown[256],sendpause,sendsave;
extern int joyxmove,joyymove,mousex,mousey;
extern boolean *mousebuttons,*joybuttons;
'''
PLATFORM = r'''
boolean usergame=false,viewactive=false,sendpause=false,sendsave=false;
boolean gamekeydown[256],mousearray[4],joyarray[5];
boolean *mousebuttons=&mousearray[1],*joybuttons=&joyarray[1];
int levelstarttic=0,starttime=0,joyxmove=0,joyymove=0,mousex=0,mousey=0;
gamestate_t wipegamestate=GS_LEVEL;
void S_ResumeSound(void) {}
int I_GetTime(void) {return 0;}
static char episode_map_name[9];
extern line_t *linespeciallist[];
extern int numlinespecials;
extern short *blockmaplump;
#include "episode-observe.inc"
'''

def build_native(out, opt, sanitize):
    _, manifest = zone.compile_trace(out, opt, sanitize)
    bodies = []
    for name in ['G_DoLoadLevel','G_InitNew']:
        body, span = gameflow.extract('g_game.c',name)
        bodies.append(body)
        manifest['adaptations'].append(dict(extraction=span))
    p = out/'game_functions.c'
    p.write_text(GLOBALS+p.read_text()+'\n'+'\n'.join(bodies)+'\n')
    host = (out/'original-host.c').read_text()
    host = host.replace('int main(int argc,char **argv) {', PLATFORM+'\nint main(int argc,char **argv) {',1)
    host = host.replace('argc!=4 && argc!=5','argc!=7',1)
    before='P_SetupLevel(1,1,1,sk_medium);ZoneStage("after_P_Setup");'
    after='''
    int episode_map=atoi(argv[4]),episode_skill=atoi(argv[5]);
    nomonsters=atoi(argv[6])!=0;
    if(episode_map<1 || episode_map>9 || episode_skill<0 || episode_skill>4)I_Error("episode selection");
    snprintf(episode_map_name,sizeof(episode_map_name),"E1M%d",episode_map);
    G_InitNew((skill_t)episode_skill,1,episode_map);ZoneStage("after_P_Setup");
    char observation_path[4096];FILE *observation;
#define EPISODE_OUTPUT(name,fn) snprintf(observation_path,sizeof(observation_path),"%s/" name,argv[2]);observation=fopen(observation_path,"wb");if(!observation)I_Error("startup observation");fn(observation);fclose(observation);
    EPISODE_OUTPUT("collision.bin",episode_collision);
    EPISODE_OUTPUT("flow.bin",episode_flow);
    EPISODE_OUTPUT("difficulty.bin",episode_difficulty);
    '''
    assert host.count(before)==1
    host=host.replace(before,after)
    (out/'original-host.c').write_text(host)
    (out/'episode-observe.inc').write_bytes((HERE/'observe.inc').read_bytes())
    entry=(HERE.parent/'phase3_zone_lifecycle/host.c').read_text().replace('argc!=4 && argc!=5','argc!=7')
    (out/'episode-host.c').write_text(entry)
    flags=[f.replace('<BUILD>',str(out)).replace('<HARNESS>',str(HERE.parent)) for f in manifest['flags']]
    cmd=['clang',*flags,'-I'+str(out),*[str(out/name) for name in renderer.UNITS+PUNITS],
         str(out/'game_functions.c'),str(out/'episode-host.c'),'-Wl,-dead_strip','-o',str(out/'episode-startup')]
    result=subprocess.run(cmd,text=True,capture_output=True)
    (out/'episode-build.log').write_text(result.stdout+result.stderr)
    if result.returncode: raise RuntimeError(result.stderr)
    manifest.update(episodeHostSha256=ref.sha(host.encode()),episodeEntrySha256=ref.sha(entry.encode()),
                    episodeGlobals=GLOBALS,episodePlatform=PLATFORM,
                    scope='Original G_InitNew/G_DoLoadLevel plus complete original P_SetupLevel and gameplay dependencies; no tics, rendering, progression or presentation')
    return out/'episode-startup',manifest

def encoded(value):
    return (json.dumps(value,indent=2,sort_keys=True)+'\n').encode()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--check',action='store_true')
    ap.add_argument('--quick',action='store_true',help='O2 development checkpoint only')
    args=ap.parse_args()
    started=time.time()
    output=ROOT/'artifacts/local/episode-startup/native'
    output.mkdir(parents=True,exist_ok=True)
    wad=ROOT/'artifacts/local/freedoom/freedoom1.wad'
    assert ref.sha(wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    commands=output/'commands.txt';commands.write_text('')
    profiles=[('O2','O2',False)] if args.quick else [('O0','O0',False),('O2','O2',False),('sanitize','O2',True)]
    binaries={};metadata={}
    for profile,opt,sanitize in profiles:
        binaries[profile],metadata[profile]=build_native(output/profile,opt,sanitize)
        print('Built original native '+profile,flush=True)
    cases=[(m,2,False) for m in range(1,10)]+[(2,0,False),(2,4,False),(2,2,True)]
    outputs={};metrics=[]
    for map_,skill,nomonsters in cases:
        name=f'E1M{map_}-skill{skill}'+('-nomonsters' if nomonsters else '')
        baseline=None
        for profile,_,_ in profiles:
            dest=output/(name+'-'+profile);dest.mkdir(exist_ok=True)
            run=subprocess.run([str(binaries[profile]),str(wad),str(dest),str(commands),str(map_),str(skill),str(int(nomonsters))],
                               capture_output=True,text=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0'})
            assert run.returncode==0 and not run.stderr,(name,profile,run.stderr)
            data={p.name:p.read_bytes() for p in dest.iterdir() if p.name in ['states.bin','collision.bin','flow.bin','difficulty.bin']}
            states=data.pop('states.bin');length=struct.unpack_from('>I',states)[0]
            assert len(states)==length+4
            data['world.bin']=states[4:]
            stages=[json.loads(line) for line in (dest/'zone-stages.jsonl').read_bytes().splitlines()]
            events=[json.loads(line) for line in (dest/'zone-events.jsonl').read_bytes().splitlines()]
            stage=next(s for s in stages if s['stage']=='after_P_Setup')
            data['zone.bin']=zone.startup_outputs(events,stage)['startup-headers.bin']
            if baseline is None:baseline=data
            else:assert data==baseline,(name,profile,'native startup divergence')
        for filename,payload in baseline.items():outputs[name+'/'+filename]=payload
        summary=json.loads((dest/'summary.json').read_text())
        metrics.append(dict(name=name,map=map_,skill=skill,nomonsters=nomonsters,summary=summary,
                            files={k:dict(bytes=len(v),sha256=ref.sha(v)) for k,v in baseline.items()}))
        print('PASS original native '+name+': world/collision/flow/difficulty/zone exact',flush=True)
    manifest=dict(goal='4.13a',upstreamCommit=ref.UPSTREAM,resourceIdentity=json.loads((ROOT/'test/fixtures/phase4_episode/catalog.json').read_text())['resourceIdentity'],
                  status='O2 development only' if args.quick else 'O0/O2/ASan+UBSan exact',profiles=[x[0] for x in profiles],cases=metrics,
                  build=metadata['O2'],sourceHashes={str(p.relative_to(ROOT)):ref.sha(p.read_bytes()) for p in [Path(__file__),HERE/'observe.inc',HERE.parent/'gameplay/observe.h',HERE.parent/'phase3_zone_lifecycle/observe.inc']},
                  notes=['Comparison-only native files; never used as engine startup input.','Existing pinned LP64, disk, pointer-array and align8 adaptations preserved.',
                         'I_ZoneBase uses calloc: same deterministic initial-zero zone policy as production. No fresh-allocation zero fill is enabled.',
                         'Sound, host clock and ST/HU startup remain declared no-op platform/UI boundaries. No renderer frames, tics or transitions run.'],
                  files={name:ref.sha(data) for name,data in outputs.items()})
    outputs['manifest.json']=encoded(manifest)
    fixture=ROOT/'test/fixtures/phase4_episode_startup'
    if not args.quick:
        for name,data in outputs.items():
            p=fixture/name
            if args.check:assert p.read_bytes()==data,'native fixture drift '+name
            else:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    else:
        for name,data in outputs.items():
            p=output/'quick'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    print(json.dumps(dict(pass_=True,cases=len(cases),profiles=manifest['profiles'],elapsedSeconds=time.time()-started)))

if __name__=='__main__':main()
