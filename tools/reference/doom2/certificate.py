#!/usr/bin/env python3
"""Check frozen source/resource/evidence identities; never substitute for execution gates."""
import hashlib,json,re,subprocess,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='3cc536dff6c84194bf3784d9183e0d082a2bcf0e'
sha=lambda b:hashlib.sha256(b).hexdigest();load=lambda p:json.loads((ROOT/p).read_text())
assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='feat/doom2-browser'
protected=[*sorted(str(p.relative_to(ROOT)) for p in (ROOT/'src/doom').glob('*.sol') if p.name not in {'g_game.sol','m_menu.sol','wi_stuff.sol','wi_stuff_types.sol','f_finale.sol'}),'src/evm/Doom.sol','src/evm/DoomGame.sol','src/evm/WadResources.sol','src/evm/EpisodeStartup.sol','src/evm/ResourceTypes.sol','src/evm/FrameProtocol.sol','src/evm/InputProtocol.sol','src/support/UltimateStartup.sol','src/support/UltimateWadResources.sol','src/support/UltimateSpeedrunProbe.sol',*sorted(str(p.relative_to(ROOT)) for p in (ROOT/'web').glob('*.mjs') if not p.name.startswith('doom2-')),'web/index.html','foundry.toml','execution-budget.json']
identities={}
for p in protected:
 expected=subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT);actual=(ROOT/p).read_bytes();assert expected==actual,'Protected baseline drift '+p;identities[p]=sha(actual)
original=ROOT/'original/DOOM';assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=original,text=True).strip()=='a77dfb96cb91780ca334d0d4cfd86957558007e0';assert not subprocess.check_output(['git','status','--short'],cwd=original,text=True)
for p in subprocess.check_output(['git','diff','--name-only',BASE],cwd=ROOT,text=True).splitlines():
 assert not (p.startswith('test/fixtures/') and not p.startswith('test/fixtures/doom2_gameflow/')),'Inherited fixture changed '+p
for p in ['artifacts/doom2/startup-all-evm.json','artifacts/doom2/focused.json','artifacts/doom2/node.json','artifacts/doom2/menu-evm.json','artifacts/doom2/browser.json']:
 r=load(p);assert r.get('pass',r.get('pass_')),p
assert len(load('artifacts/doom2/startup-all-evm.json')['cases'])==32
assert load('artifacts/doom2/focused.json')['counts']==[132,0,0,132]
assert 'pass 81' in (ROOT/'artifacts/doom2/node.log').read_text()
for m,count in [(1,192),(7,237)]:
 base=f'artifacts/doom2/MAP{m:02d}';r=load(base+'/evm-video.json');v=load(base+'/verification.json');media=load(base+'/media.json');assert r['pass'] and r['verifiedTics']==count and len(r['frames'])==count and r['memoryProfile']=='virtual' and r['exit']['reached'];assert v['mediaVerified'] and v['evidenceVerified'] and v['recordingComplete'];assert load(base+'/pixel-domain.json')['allCommonNativePixelsOutsideVirtualSourcesExact'];assert media['fps']==35 and media['encodedFrames']==count
 mp4=ROOT/f'artifacts/local/doom2/MAP{m:02d}/full-rate'/media['mp4'];assert sha(mp4.read_bytes())==media['mp4Sha256']
pin=load('artifacts/doom2/resource-pin.json');assert pin['chunks']==889 and pin['lumps']==2919
payloads={}
for p in sorted((ROOT/'artifacts/doom2').rglob('*')):
 if p.is_file() and p.name!='certificate.json':payloads[str(p.relative_to(ROOT))]=sha(p.read_bytes())
for p in sorted((ROOT/'web/doom2-assets').glob('*.json')):payloads[str(p.relative_to(ROOT))]=sha(p.read_bytes())
result=dict(pass_=True,verifiedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),baseline=BASE,originalCommit='a77dfb96cb91780ca334d0d4cfd86957558007e0',resourceIdentity=pin['resourceIdentity'],protectedBaselineSHA256=identities,evidenceSHA256=payloads,scope='Identity/metadata certificate checked after independent native/EVM/browser/receipt/media acceptance; no complete historical suite or universal DOOM II correctness claim')
(ROOT/'artifacts/doom2/certificate.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(pass_=True,protectedSources=len(identities),evidenceFiles=len(payloads))))
