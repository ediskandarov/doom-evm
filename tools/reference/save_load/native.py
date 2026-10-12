#!/usr/bin/env python3
"""Actual pinned original p_saveg and G_SaveGame/G_LoadGame request semantics.

The exact EVM archive deliberately retains information original savegames lose.
This finite gate executes original archive/unarchive functions in a real E1M1
world; it does not label the extended EVM format original-binary compatible.
"""
import argparse
import importlib.util
import json
import os
import subprocess
import re
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE.parent))
import reference as ref
spec=importlib.util.spec_from_file_location('save_native_gameplay_builder',HERE.parent/'gameplay/build.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

PROBE=r'''
#include "p_saveg.h"
boolean sendsave=false;
int savegameslot;
char savedescription[32], savename[256];
static void saveProbe(void) {
    G_SaveGame(2,"EVM DISCOVERY");
    if(!sendsave || savegameslot!=2 || strcmp(savedescription,"EVM DISCOVERY"))I_Error("save request");
    G_LoadGame("doomsav2.dsg");
    if(gameaction!=ga_loadgame || strcmp(savename,"doomsav2.dsg"))I_Error("load request");
    gameaction=ga_nothing;
    players[0].health=73;players[0].mo->health=73;players[0].ammo[0]=43;
    players[0].message="saved message";
    mobj_t *other=NULL;
    for(thinker_t*t=thinkercap.next;t!=&thinkercap;t=t->next)
        if(t->function.acp1==(actionf_p1)P_MobjThinker && t!=(thinker_t*)players[0].mo){other=(mobj_t*)t;break;}
    if(!other)I_Error("missing original actor");
    players[0].mo->target=other;players[0].attacker=other;sectors[0].soundtarget=other;
    int floor=sectors[0].floorheight+123;sectors[0].floorheight=floor;
    int rng=prndindex,random=rndindex;
    byte *buffer=malloc(1024*1024);save_p=buffer;
    P_ArchivePlayers();P_ArchiveWorld();P_ArchiveThinkers();P_ArchiveSpecials();
    long size=save_p-buffer;
    if(size<=0||size>1024*1024)I_Error("archive bounds");
    players[0].health=7;players[0].ammo[0]=0;sectors[0].floorheight=0;
    save_p=buffer;P_UnArchivePlayers();P_UnArchiveWorld();P_UnArchiveThinkers();P_UnArchiveSpecials();
    if(players[0].health!=73 || players[0].mo->health!=73 || players[0].ammo[0]!=43)I_Error("player archive");
    if(players[0].mo->target || players[0].attacker || players[0].message || sectors[0].soundtarget)I_Error("original reference clearing");
    if(sectors[0].floorheight!=(floor>>FRACBITS)*FRACUNIT)I_Error("original short world precision");
    if(prndindex!=rng || rndindex!=random)I_Error("archive unexpectedly touched RNG");
    if(save_p-buffer!=size)I_Error("unarchive cursor");
    printf("SAVE_RESULT {\"archiveBytes\":%ld,\"health\":%d,\"ammo\":%d,\"floorBefore\":%d,\"floorAfter\":%d,\"prndindex\":%d,\"rndindex\":%d,\"targetsCleared\":true,\"messageCleared\":true,\"queuesExact\":true}\n",
        size,players[0].health,players[0].ammo[0],floor,sectors[0].floorheight,prndindex,rndindex);
    free(buffer);
}
'''

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--wad',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=ROOT/'artifacts/local/save-load/native');args=parser.parse_args()
    assert ref.sha(args.wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip()==ref.UPSTREAM
    report={'kind':__doc__,'pass':False,'upstreamCommit':ref.UPSTREAM,'profiles':[],
            'sourceHashes':{n:ref.sha((ref.SOURCE/n).read_bytes()) for n in ['p_saveg.c','p_saveg.h','g_game.c','m_menu.c']},
            'scope':['Original p_saveg archive/unarchive in authentic E1M1; original save/load request queuing.',
                     'G_DoLoadGame full action is source-reviewed, not executed by this archive-only gate.',
                     'Inherited LP64 align8/grouped-pointer adapters; archive PADSAVEP also adapted4→8 for LP64 typed records.',
                     'Unmodified archive align4 UBSan failure preserved under artifacts/local/save-load/native-v2/sanitize.'],
            'archiveLayoutAdaptation':'PADSAVEP uses uintptr_t and alignment8; original sizeof/memcpy/swizzling/archive control flow retained. Binary compatibility excluded.'}
    for label,opt,sanitize in [('O0','O0',False),('O2','O2',False),('sanitize','O2',True)]:
        out=args.output/label;builder.build(out,opt,sanitize)
        save,span1=builder.extract('g_game.c','G_SaveGame');load,span2=builder.extract('g_game.c','G_LoadGame')
        p=out/'game_functions.c';p.write_text(p.read_text()+'\nextern boolean sendsave;extern int savegameslot;extern char savedescription[32],savename[256];\n'+save+'\n'+load+'\n')
        source=(ref.SOURCE/'p_saveg.c').read_text()
        source,count=re.subn(r'#define PADSAVEP\(\)[^\n]*',
            '#define PADSAVEP() save_p += (8 - ((uintptr_t) save_p & 7)) & 7',source)
        assert count==1
        (out/'p_saveg.c').write_text(source)
        host=(HERE.parent/'gameplay/host.c').read_text();before='int main(int argc,char **argv) {';assert host.count(before)==1
        host=host.replace(before,PROBE+'\n'+before)
        before='    P_SetupLevel(1,1,1,sk_medium);';assert host.count(before)==1
        host=host.replace(before,before+'\n    saveProbe();return 0;')
        (out/'save-host.c').write_text(host)
        manifest=json.loads((out/'gameplay-build-manifest.json').read_text())
        flags=[f.replace('<HARNESS>',str(HERE.parent)) for f in manifest['flags']]
        cmd=['clang',*flags,'-I'+str(out),'-I'+str(HERE.parent/'gameplay'),
             *[str(out/n) for n in builder.renderer.UNITS+builder.PUNITS],str(out/'p_saveg.c'),
             str(out/'game_functions.c'),str(out/'save-host.c'),'-Wl,-dead_strip','-o',str(out/'save-native')]
        result=subprocess.run(cmd,text=True,capture_output=True);(out/'save-build.log').write_text(result.stdout+result.stderr)
        assert result.returncode==0,result.stderr
        (out/'empty-commands').write_text('')
        env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0');env.pop('DOOM_ORACLE_ALLOCATION_FILL',None)
        run=subprocess.run([str(out/'save-native'),str(args.wad),str(out),str(out/'empty-commands')],env=env,text=True,capture_output=True)
        (out/'save-run.log').write_text(run.stdout+run.stderr);assert run.returncode==0,run.stderr
        value=json.loads(next(line.split('SAVE_RESULT ',1)[1] for line in run.stdout.splitlines() if 'SAVE_RESULT ' in line))
        if report['profiles']:assert value==report['profiles'][0]['result']
        report['profiles'].append({'profile':label,'result':value,'extractions':[span1,span2],
            'command':cmd,'executableSha256':ref.sha((out/'save-native').read_bytes()),'hostSha256':ref.sha(host.encode()),
            'archiveSourceSha256':ref.sha(source.encode()),
            'buildManifestSha256':ref.sha((out/'gameplay-build-manifest.json').read_bytes())})
        print('PASS original save archive',label,value,flush=True)
    report['pass']=True;path=ROOT/'artifacts/save-load/native-archive.json';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
