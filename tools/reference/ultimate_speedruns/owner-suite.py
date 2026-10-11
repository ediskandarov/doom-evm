#!/usr/bin/env python3
"""Independent resumable map jobs; immutable old results; bounded local concurrency.

Wait for this owner's already launched jobs with --wait-for. This reads their
completed reports only; it never attaches to a runtime. Every new Anvil is
started/stopped by its own pinned runner, which refuses occupied ports.
"""
import argparse,concurrent.futures,hashlib,json,os,shutil,subprocess,time,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent;LOCAL=ROOT/'artifacts/local/ultimate-speedruns'
commit_lock=threading.Lock();process_lock=threading.Lock();owned_children=set()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ap=argparse.ArgumentParser();ap.add_argument('--maps',default='3,5,6,8,1,2,4,7,9');ap.add_argument('--wait-for',default='');ap.add_argument('--concurrency',type=int,default=2);ap.add_argument('--commit',action='store_true');a=ap.parse_args()
assert 1<=a.concurrency<=2
maps=[int(x) for x in a.maps.split(',')];waiting=[int(x) for x in a.wait_for.split(',') if x];assert all(1<=m<=9 for m in maps+waiting)
assert len(set(maps))==len(maps) and len(set(waiting))==len(waiting)
maps=[m for m in maps if m not in waiting]
assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='feat/ultimate-episode-speedruns'
def base(m):
 p=LOCAL/f'E1M{m}';return p/'alternatives/sedlo-046' if m==8 else p
def rec(m):return base(m)/'owner-v1/full-rate'
def run(cmd,log):
 with log.open('ab') as f:
  f.write(('\nCOMMAND '+json.dumps([str(c) for c in cmd])+'\n').encode());f.flush()
  p=subprocess.Popen([str(c) for c in cmd],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
  with process_lock:owned_children.add(p)
  try:p.wait()
  finally:
   with process_lock:owned_children.discard(p)
 assert p.returncode==0,f'failed {cmd[1]} ({p.returncode}); see {log}'
def verify(m):
 b=base(m);r=rec(m);log=b/'owner-v1-verification.log';n=json.loads((b/'native-result.json').read_text())
 variant='verify-owner.py' if n['allProfilesExact'] else 'verify-owner-domain.py'
 run(['python3',HERE/variant,b,r,'--native-frames',b/'native-full'],log)
 run(['python3',HERE/'pixel-owner-domain.py',b,r],log)
 manifest=json.loads((r/'frame-manifest.json').read_text())
 if not manifest.get('media'):run(['python3',HERE/'encode.py',r],log)
 run(['python3',HERE/variant,b,r,'--native-frames',b/'native-full'],log)
 if m in [1,2,4,7,9]:
  old=json.loads((b/'full-rate/frame-manifest.json').read_text());new=json.loads((r/'frame-manifest.json').read_text())
  assert [(f['tic'],f['indexed8Sha256'],f['virtualSamples']) for f in old['frames']]==[(f['tic'],f['indexed8Sha256'],[{k:v for k,v in s.items() if k not in ('addressDomain','ownerSlotIndex')} for s in f['virtualSamples']]) for f in new['frames']],f'accepted-frame regression E1M{m}'
  (r/'accepted-regression.json').write_text(json.dumps(dict(pass_=True,frames=len(new['frames']),oldManifestSHA256=sha(b/'full-rate/frame-manifest.json'),newManifestSHA256=sha(r/'frame-manifest.json'),scope='All indexed8 hashes and original provenance4 samples identical; accepted recording preserved'),indent=2)+'\n')
 out=ROOT/'artifacts/ultimate-speedruns'/b.relative_to(LOCAL)/'owner-v1'
 if (out/'evidence-manifest.json').exists():
  # Reverification may not rewrite an accepted milestone's source/time identity.
  accepted=json.loads((out/'result.json').read_text())
  for file in json.loads((out/'evidence-manifest.json').read_text())['files']:
   assert sha(ROOT/file['path'])==file['SHA256'],file['path']+' accepted evidence drift'
  return dict(map=f'E1M{m}',pass_=True,frames=accepted['frames']['rendered'],MP4=accepted['media']['MP4'],acceptedEvidencePreserved=True)
 run(['python3',HERE/'checkpoint-owner-result.py',f'E1M{m}','--base',b,'--recording',r],log)
 out=ROOT/'artifacts/ultimate-speedruns'/b.relative_to(LOCAL)/'owner-v1'
 result=json.loads((out/'result.json').read_text());p=ROOT/f'docs/ULTIMATE-E1M{m}-OWNER-V1.md'
 p.write_text(f'''# E1M{m} owner-v1 recording\n\nAuthentic {result['demo']['originalName']} by {result['demo']['author']};\n[original download]({result['demo']['URL']}). Demo SHA256\n`{result['demo']['SHA256']}`; classic Ultimate DOOM MD5\n`{result['IWAD']['MD5']}`, SHA256 `{result['IWAD']['SHA256']}`.\n\nNative gameplay and every EVM snapshot agree: {result['EVMGameplay']['tics']}\ntics, {result['EVMGameplay']['observations']} observations and genuine exit.\n{result['frames']['rendered']} mined EVM frames; complete35FPS MP4 at\n`{result['media']['MP4']}`.\n\nSupported common-native pixels outside virtual destinations agree exactly;\n{result['supportedPixelDomain']['commonNativePixelsChecked']} comparisons.\nVirtual zone uses: {result['ownerPointerProvenance']['virtualZoneUses']};\nvirtual owner-slot uses: {result['ownerPointerProvenance']['virtualOwnerUses']}.\nThese address-derived samples remain deterministic virtual bytes, not proof of\nuniversal native framebuffer equality. Compatibility remains RESTRICT.\n\nTotal recording gas: {result['gas']['totalVerifiedRecording']}; capture RPC\nseconds: {result['runtime']['captureRPCSeconds']}; replay RPC seconds:\n{result['runtime']['successfulReplayRPCSeconds']}. The evidence records measured\nstart/end/session times and all local Anvil arguments and budgets.\n\n[Evidence manifest](../{out.relative_to(ROOT)}/evidence-manifest.json),\n[result](../{out.relative_to(ROOT)}/result.json),\n[all virtual uses](../{out.relative_to(ROOT)}/virtual-samples.json).\nPrior accepted/partial recordings and reports remain preserved.\nUnresolved recording failure: none. Render observations use temporary copies,\nas in the accepted infrastructure; production UI/history acceptance is outside\nthis experiment. See [the source justification](ULTIMATE-OWNER-POINTERS.md).\n''')
 if a.commit:
  with commit_lock:
   subprocess.run(['git','add',str(out.relative_to(ROOT)),str(p.relative_to(ROOT))],cwd=ROOT,check=True)
   subprocess.run(['git','commit','-m',f'✅ Verify full-rate E1M{m} owner-profile recording'],cwd=ROOT,check=True)
 return dict(map=f'E1M{m}',pass_=True,frames=result['frames']['rendered'],MP4=result['media']['MP4'])
def job(m):
 try:
  b=base(m);r=rec(m);r.mkdir(parents=True,exist_ok=True);report=r/'evm.json'
  if not report.exists() or not json.loads(report.read_text())['pass']:
   n=json.loads((b/'native-result.json').read_text());variant='evm-owner.mjs' if n['allProfilesExact'] else 'evm-owner-domain.mjs'
   cmd=['node',HERE/variant,'--artifacts',b,'--output-prefix',r/'evm','--port',str(18640+m),'--checkpoint-every','100']
   if (r/'evm.checkpoint.json').exists():cmd.append('--resume')
   run(cmd,b/'owner-v1-run.log')
  return verify(m)
 except Exception as e:return dict(map=f'E1M{m}',pass_=False,error=str(e),evidence=str(rec(m).relative_to(ROOT)))
results=[];futures={};last_cleanup=0
# Externally launched jobs are this owner's. Read completed reports only;
# never attach to any Anvil or signal a process not launched by this suite.
with concurrent.futures.ThreadPoolExecutor(max_workers=a.concurrency) as pool:
 queue=list(maps)
 while waiting or futures or queue:
  for m in waiting[:]:
   p=rec(m)/'evm.json'
   if p.exists():
    r=json.loads(p.read_text())
    if r.get('ownedRuntimeStopped'):
     if r['pass']:futures[pool.submit(job,m)]=m
     else:results.append(dict(map=f'E1M{m}',pass_=False,error=r.get('error'),evidence=str(p.relative_to(ROOT))))
     waiting.remove(m)
  done=[f for f in futures if f.done()]
  for f in done:
   result=f.result();results.append(result);futures.pop(f);print(json.dumps(result),flush=True)
  while len(futures)+len(waiting)<a.concurrency and queue:
   m=queue.pop(0);futures[pool.submit(job,m)]=m
  free=shutil.disk_usage(ROOT).free
  if time.time()-last_cleanup>60:
   roots=[rec(m).parent for m in maps+([3,8] if a.wait_for else []) if rec(m).exists()]
   if roots:
    p=subprocess.run(['python3',str(HERE/'clean-checkpoints.py'),*[str(r) for r in roots],'--audit-log',str(LOCAL/'owner-cleanup.jsonl')],cwd=ROOT,capture_output=True,text=True)
    assert p.returncode==0,p.stderr
    print(p.stdout.strip(),flush=True)
   last_cleanup=time.time()
  if free<4*1024**3:
   with process_lock:
    for child in owned_children:
     if child.poll() is None:child.terminate()
   raise RuntimeError('Disk reserve below4GiB; requested recoverable stops from owned children')
  (LOCAL/'owner-suite.json').write_text(json.dumps(dict(results=results,running=[f'E1M{m}' for m in futures.values()],waitingForOwnedReports=waiting,queue=queue,diskFreeBytes=free),indent=2)+'\n')
  time.sleep(10)
(LOCAL/'owner-suite.json').write_text(json.dumps(dict(results=results,complete=all(r['pass_'] for r in results)),indent=2)+'\n')
assert all(r['pass_'] for r in results),results
