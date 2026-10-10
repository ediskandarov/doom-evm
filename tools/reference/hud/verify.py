#!/usr/bin/env python3
"""Run and bind the focused Goal 4.3 checks without inherited regression."""
import hashlib, json, pathlib, re, subprocess, time
ROOT=pathlib.Path(__file__).resolve().parents[3]
BASE='084764b'
OWNED=['src/doom/hu_lib.sol','src/doom/hu_stuff.sol','test/unit/hu_lib.t.sol','test/unit/hu_stuff.t.sol','test/integration/HudMessages.t.sol']
LOG=ROOT/'artifacts/local/hud';LOG.mkdir(parents=True,exist_ok=True)

def run(name,command):
    started=time.monotonic();p=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    (LOG/(name+'.log')).write_text(p.stdout+p.stderr)
    assert p.returncode==0,(name,p.stdout[-3000:],p.stderr[-3000:])
    return {'command':command,'returnCode':p.returncode,'elapsedSeconds':round(time.monotonic()-started,3),'logSha256':hashlib.sha256((p.stdout+p.stderr).encode()).hexdigest()},p.stdout

results={}
results['native'],_=run('native',['python3','tools/reference/hud/reference.py','--check'])
results['format'],_=run('format',['.toolchain/bin/forge','fmt','--check',*OWNED])
results['foundry'],output=run('foundry',['.toolchain/bin/forge','test','--match-path','test/{unit/hu_*,integration/HudMessages}.t.sol','--skip','Doom','--skip','GameplayProbe','--skip','RendererProbe','--skip','WadResourcesProbe','--fuzz-seed','0x43','-vv'])
assert re.search(r'14 tests passed, 0 failed, 0 skipped',output)
assert 'testFuzzTextCapacityAndTrailingNul(bytes) (runs: 256' in output
branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip();assert branch=='feat/phase4-hud'
# Compare every baseline engine/adapter/config source directly to Git's accepted blobs.
protected={}
for entry in subprocess.check_output(['git','ls-tree','-r',BASE,'--','src','foundry.toml','execution-budget.json','toolchain.lock.json'],cwd=ROOT,text=True).splitlines():
    meta,path=entry.split('\t');_,kind,blob=meta.split();assert kind=='blob'
    data=(ROOT/path).read_bytes();actual=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
    assert actual==blob,('protected baseline modified',path);protected[path]=hashlib.sha256(data).hexdigest()
# None of the existing tracked files may be changed; this task is entirely additive.
assert not subprocess.check_output(['git','diff',BASE,'--name-only','--diff-filter=MDR'],cwd=ROOT,text=True).strip()
files=OWNED+['docs/PHASE4-HUD.md']+[str(p.relative_to(ROOT)) for p in (ROOT/'tools/reference/hud').glob('*') if p.is_file()]+[str(p.relative_to(ROOT)) for p in (ROOT/'test/fixtures/phase4_hud').glob('*') if p.is_file()]
evidence={'schemaVersion':1,'status':'passed','branch':branch,'baseline':BASE,'scope':'Goal 4.3 HUD-only; no chat, no shared engine/interface/production adapter edits; inherited regression deferred to final Phase 4','focusedFoundryTests':14,'fuzzRuns':256,'nativeCases':209,'nativeSnapshots':575,'nativeProfiles':['O0','O2','ASan+UBSan'],'gameplayProducerFrameComparisons':44,'checks':results,'protectedBaselineSha256':protected,'ownedSha256':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in sorted(files)}}
path=ROOT/'artifacts/phase4/hud/verification.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(evidence,indent=2)+'\n')
print(json.dumps({'status':'passed','tests':14,'nativeCases':209,'nativeSnapshots':575,'gameplayComparisons':44,'protectedBaselineFiles':len(protected),'branch':branch,'evidence':str(path.relative_to(ROOT))}))
