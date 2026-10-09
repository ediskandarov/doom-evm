#!/usr/bin/env python3
"""Run all Phase 0 gates; retain command logs, exit codes and source identities."""
import hashlib,json,os,pathlib,signal,subprocess,sys,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/local/verification'
OUT.mkdir(parents=True,exist_ok=True)
commands=[
 ('toolchain',['python3','scripts/check-toolchain.py']),
 ('schemas',['python3','scripts/check-schemas.py']),
 ('format',['.toolchain/bin/forge','fmt','--check']),
 ('build',['.toolchain/bin/forge','build','--force']),
 ('foundry-tests',['.toolchain/bin/forge','test','--fuzz-seed','0x44','-vv']),
 ('protocol-tests',['node','--test','tools/transport/protocol.test.mjs']),
 ('browser-failure-cleanup',['node','--test','tools/transport/lifecycle.test.mjs']),
 ('stack-compile',['python3','scripts/stack-pressure.py']),
 ('launcher',['scripts/start-anvil.sh','--check','--quiet']),
 ('runtime-limits',['python3','scripts/probe-limits.py']),
 ('transport',['node','tools/transport/benchmark.mjs']),
 ('browser',['node','tools/transport/browser-check.mjs']),
]
report={'scope':'Phase 0 only; no engine port or C equivalence','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'results':[]}
report['source_sha256']={}
for directory,patterns in [('src',['*.sol']),('test',['*.sol']),('scripts',['*.py','*.sh']),('tools/transport',['*.mjs']),('web',['*.mjs','*.html','palette.synthetic.json']),('schemas',['*.json'])]:
 for pattern in patterns:
  for path in sorted((ROOT/directory).rglob(pattern)):
   report['source_sha256'][str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
for name in ('foundry.toml','toolchain.lock.json'):
 report['source_sha256'][name]=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
env=dict(os.environ,ANVIL_PORT='18545')
for name,args in commands:
 print(f'Running {name}...',flush=True)
 started=time.monotonic()
 with (OUT/(name+'.log')).open('w') as log:
  process=subprocess.Popen(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
  # The integrated Phase 2 sources took 207s to compile on the pinned host.
  # Allow headroom for a forced build; preserve every gate and other timeout.
  try: code=process.wait(timeout=600 if name=='build' else 180)
  except subprocess.TimeoutExpired:
   os.killpg(process.pid,signal.SIGTERM)
   try: process.wait(timeout=5)
   except subprocess.TimeoutExpired: os.killpg(process.pid,signal.SIGKILL);process.wait()
   code=124
 result={'gate':name,'command':args,'exit_code':code,'elapsed_seconds':round(time.monotonic()-started,3),'log':str((OUT/(name+'.log')).relative_to(ROOT))}
 report['results'].append(result)
 report['passed']=len(report['results'])==len(commands) and all(r['exit_code']==0 for r in report['results'])
 (OUT/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
 if code:
  print((OUT/(name+'.log')).read_text()[-6000:])
  raise SystemExit(f'FAILED: {name}; see {OUT}')
 print(f'PASS {name} ({result["elapsed_seconds"]}s)',flush=True)
print(f'PASS: all {len(commands)} Phase 0 gates; {OUT / "summary.json"}')
