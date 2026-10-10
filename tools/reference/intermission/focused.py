#!/usr/bin/env python3
"""Build/run only WI and its video/RNG dependency tests, leaving shared config intact."""
import datetime, hashlib, json, pathlib, re, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[3]
keep={'Intermission.t.sol','v_video.t.sol','m_random.t.sol','IntermissionProbe.sol',
      'IntermissionFixture.sol','wi_stuff.sol','wi_stuff_types.sol'}
skips=sorted({p.name for d in ['src','test'] for p in (ROOT/d).rglob('*.sol') if p.name not in keep})
cmd=[str(ROOT/'.toolchain/bin/forge'),'test','--no-dynamic-test-linking',
     '--match-path','test/{intermission/Intermission,unit/v_video,unit/m_random}.t.sol','-vv','--skip',*skips]
out=ROOT/'artifacts/local/intermission';out.mkdir(parents=True,exist_ok=True)
watched=['src/doom/wi_stuff.sol','src/doom/wi_stuff_types.sol','src/support/IntermissionFixture.sol',
         'src/support/IntermissionProbe.sol','test/intermission/Intermission.t.sol','src/doom/v_video.sol',
         'src/doom/m_random.sol','src/doom/r_data.sol','foundry.toml','execution-budget.json',
         'tools/reference/intermission/focused.py','test/fixtures/phase4_intermission/native.json',
         'test/fixtures/phase4_intermission/cases.bin']
identities={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in watched}
start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
run=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
log=run.stdout+run.stderr;(out/'focused.log').write_text(log)
counts=re.search(r'(\d+) tests passed, (\d+) failed, (\d+) skipped \((\d+) total tests\)',log)
report=dict(goal='4.14a',pass_=run.returncode==0,returnCode=run.returncode,start=start,
            seconds=time.monotonic()-timer,command=['.toolchain/bin/forge',*cmd[1:]],sourceSha256=identities,counts=list(map(int,counts.groups())) if counts else None)
assert identities=={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in watched},'source changed during focused run'
(out/'focused.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report));print(log[-6000:]);raise SystemExit(run.returncode)
