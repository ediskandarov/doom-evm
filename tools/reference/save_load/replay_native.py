#!/usr/bin/env python3
"""Fresh finite original-C worlds/frames for save-point continuation comparisons."""
import argparse,importlib.util,json,os,subprocess,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE.parent/'gameplay'))
import build as builder
from build import ref
spec=importlib.util.spec_from_file_location('save_rocket_native',HERE.parent/'gameplay_projectile/reference.py')
rocket=importlib.util.module_from_spec(spec);spec.loader.exec_module(rocket)

CASES=[('movement',0,160,80),('combat-arena',1,100,35),('door-use',4,125,20),
       ('projectile-arena',6,65,40),('platform-active',7,125,110)]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--wad',type=Path,required=True)
    ap.add_argument('--output',type=Path,default=ROOT/'artifacts/local/save-load/replay-native');a=ap.parse_args()
    assert ref.sha(a.wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    a.output.mkdir(parents=True,exist_ok=True)
    report={'kind':__doc__,'pass':False,'upstreamCommit':ref.UPSTREAM,'cases':[],'profiles':[],
            'scope':'Direct original ticcmds, no ST/HU ticks; controlled original-object arena/platform fixtures; native pixels never submitted to EVM.'}
    cases=[]
    for name,scenario,count,checkpoint in CASES:
        if name=='platform-active':rows=[[0,0,0,0,0] for _ in range(count)]
        else:
            folder=ROOT/'test/fixtures/gameplay_projectile' if scenario==6 else ROOT/'test/fixtures/gameplay'/name
            rows=[list(map(int,line.split())) for line in (folder/'commands.txt').read_text().splitlines()[:count]]
        for i,row in enumerate(rows):row[4]=int(i+1 in [1,checkpoint,count])
        path=a.output/(name+'.commands');path.write_text(''.join(' '.join(map(str,row))+'\n' for row in rows))
        cases.append((name,scenario,count,checkpoint,path,rows));report['cases'].append({'name':name,'scenario':scenario,'tics':count,'checkpoint':checkpoint,'commandsSha256':ref.sha(path.read_bytes())})
    canonical={}
    for profile,opt,sanitize in [('O0','O0',False),('O2','O2',False),('sanitize','O2',True)]:
        out=a.output/profile;exe=builder.build(out/'engine',opt,sanitize)
        manifest=json.loads((out/'engine/gameplay-build-manifest.json').read_text())
        # Native fixture only: original EV_DoPlat against authentic sector/line0.
        host=(HERE.parent/'gameplay/host.c').read_text();needle='    P_SetupLevel(1,1,1,sk_medium);';assert host.count(needle)==1
        host=host.replace(needle,needle+'\n    if(getenv("SAVE_PLATFORM_FIXTURE")){sectors[0].tag=9999;lines[0].tag=9999;EV_DoPlat(&lines[0],perpetualRaise,0);}')
        (out/'engine/platform-host.c').write_text(host)
        flags=[f.replace('<HARNESS>',str(HERE.parent)) for f in manifest['flags']]
        cmd=['clang',*flags,'-I'+str(out/'engine'),'-I'+str(HERE.parent/'gameplay'),
             *[str(out/'engine'/n) for n in builder.renderer.UNITS+builder.PUNITS],str(out/'engine/game_functions.c'),
             str(out/'engine/platform-host.c'),'-Wl,-dead_strip','-o',str(out/'engine/platform')]
        compile_=subprocess.run(cmd,text=True,capture_output=True);(out/'engine/platform-build.log').write_text(compile_.stdout+compile_.stderr);assert compile_.returncode==0,compile_.stderr
        rocket_exe,rocket_manifest=rocket.compile_profile(out/'rocket',opt,sanitize)
        report['profiles'].append({'profile':profile,'engineManifestSha256':ref.sha((out/'engine/gameplay-build-manifest.json').read_bytes()),
            'platformHostSha256':ref.sha(host.encode()),'platformCommand':cmd,'rocketManifest':rocket_manifest})
        for name,scenario,count,checkpoint,path,rows in cases:
            dest=out/name;dest.mkdir(parents=True,exist_ok=True)
            env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0');env.pop('DOOM_ORACLE_ALLOCATION_FILL',None);env.pop('SAVE_PLATFORM_FIXTURE',None)
            if scenario==7:env['SAVE_PLATFORM_FIXTURE']='1'
            executable=rocket_exe if scenario==6 else out/'engine/platform' if scenario==7 else exe
            argument=name if scenario in [1,4] else 'ordinary'
            run=subprocess.run([str(executable),str(a.wad),str(dest),str(path),argument],text=True,capture_output=True,env=env)
            (dest/'run.log').write_text(run.stdout+run.stderr);assert run.returncode==0 and not run.stderr,(profile,name,run.stderr)
            outputs={p.name:p.read_bytes() for p in dest.glob('*.bin')}
            if name not in canonical:canonical[name]=outputs
            assert outputs==canonical[name],(profile,name,'native worlds/frames differ')
            print('PASS fresh original continuation',profile,name,count,'tics',flush=True)
    for row in report['cases']:
        folder=a.output/'O2'/row['name'];row['files']={p.name:ref.sha(p.read_bytes()) for p in folder.glob('*.bin')}
    report['pass']=True;(a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'artifacts/save-load/native-continuation.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
