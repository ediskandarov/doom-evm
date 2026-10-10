#!/usr/bin/env python3
"""Diagnose original-C intercept overflow before its out-of-array write."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from replay import renderer,PUNITS
ap=argparse.ArgumentParser();ap.add_argument('directory',type=Path);a=ap.parse_args();base=a.directory.resolve();out=base/'intercept-audit';build=out/'build';source=ROOT/'artifacts/local/episode-speedruns/native-build-O2'
shutil.copytree(source,build,dirs_exist_ok=True);p=build/'p_maputl.c';original=p.read_text();needle='    intercept_p->frac = frac;';assert original.count(needle)==2
instrumented='#include "i_system.h"\nextern int gametic;\n'+original.replace(needle,'    if (intercept_p - intercepts >= MAXINTERCEPTS) I_Error("SPEEDRUN_INTERCEPT_OVERFLOW gametic=%d count=%ld max=%d", gametic, (long)(intercept_p-intercepts), MAXINTERCEPTS);\n'+needle);p.write_text(instrumented)
m=json.loads((source/'speedrun-build-manifest.json').read_text());flags=[f.replace('<BUILD>',str(build)).replace('<HARNESS>',str(ROOT/'tools/reference')) for f in m['flags']]
command=['clang',*flags,'-I'+str(build),*[str(build/n) for n in renderer.UNITS+PUNITS],str(build/'game_functions.c'),str(build/'episode-host.c'),'-Wl,-dead_strip','-o',str(build/'speedrun')];c=subprocess.run(command,capture_output=True);(out/'build.log').write_bytes(c.stdout+c.stderr);assert c.returncode==0,c.stderr.decode()
(out/'run').mkdir(exist_ok=True);settings=json.loads((base/'tape.json').read_text())['header'];run=[str(build/'speedrun'),str(ROOT/'artifacts/local/ultimate-doom/DOOM.WAD'),str(out/'run'),str(base/'commands.txt'),str(settings['map']),str(settings['skill']),str(settings['nomonsters'])];r=subprocess.run(run,capture_output=True);(out/'stdout.log').write_bytes(r.stdout);(out/'stderr.log').write_bytes(r.stderr)
sha=lambda b:hashlib.sha256(b).hexdigest();result=dict(returncode=r.returncode,command=run,diagnostic=r.stderr.decode(errors='replace'),scope='Observation-only guard before original out-of-array intercept write; no upstream source or accepted oracle is changed.',originalGeneratedSourceSha256=sha(original.encode()),instrumentedSourceSha256=sha(instrumented.encode()),toolSha256=sha(Path(__file__).read_bytes()),nativeFailurePreserved=True)
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
