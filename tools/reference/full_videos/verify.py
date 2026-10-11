#!/usr/bin/env python3
"""Read-only native/pixel/frame/input/receipt gate; finite virtual-domain scope remains explicit."""
import argparse,json,gzip,hashlib,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sha=lambda b:hashlib.sha256(b).hexdigest()
ap=argparse.ArgumentParser();ap.add_argument('recording',type=Path);ap.add_argument('--partial',action='store_true');a=ap.parse_args();out=a.recording.resolve();r=json.loads((out/'recording.json').read_text());m=r['identity']['map'];selection=json.loads((out/'native-profile.json').read_text()) if (out/'native-profile.json').exists() else None;native=ROOT/selection['gameplayDirectory'] if selection else ROOT/f'artifacts/local/full-videos/E1M{m}/native';g=json.loads((native/'gameplay.json').read_text());base=ROOT/f'artifacts/local/ultimate-speedruns/E1M{m}'
if m==8:base=base/'alternatives/sedlo-046'
n=json.loads((base/'native-result.json').read_text());assert sha((base/'source-download').read_bytes())==r['identity']['demoSha256'];t=json.loads((base/'tape.json').read_text());raw=b''.join(bytes.fromhex(x['rawHex']) for x in t['commands']);assert sha(raw)==r['identity']['commandBytesSha256'];assert raw==(base/'source-download').read_bytes()[13:13+len(raw)]
if selection:
 assert sha((native/'gameplay.json').read_bytes())==selection['gameplayManifestSHA256'];assert g['pass_'] and g['nativeUIResourceProfile']=='all UI including ST_lib borrowed'
report=dict(nativeReferenceProfile=selection,map=m,scope='Finite native comparison with explicit virtual destinations; no universal native pointer-pixel equality.',gameplay={},nativeUIFrames=0,wipeFrames=r['wipeFrames'],commonNativePixelsChecked=0,virtualZoneUses=0,virtualOwnerUses=0,wholeNativeFramesEqual=0,frames=r.get('totalVideoFrames',len(r['frames'])),pass_=False)
for tx in r['transactions']:
 b=(out/tx['file']).read_bytes();assert sha(b)==tx['receiptSha256'];receipt=json.loads(gzip.decompress(b));assert receipt['transactionHash']==tx['hash'];assert receipt['status']=='0x1'
for f in r['frames']:
 pixels=(out/f['file']).read_bytes();pal=(out/f['paletteFile']).read_bytes();assert len(pixels)==64000 and sha(pixels)==f['sha256'] and len(pal)==768 and sha(pal)==f['paletteSha256']
 # The first gameplay target is visible in the last entry-wipe frame.
 if f['kind']==0 or f['kind']==2 and f['gameplayTic']==1 and (f['frameId']==len(r['frames']) or r['frames'][f['frameId']]['kind']!=2):
  tic=f['gameplayTic'];expected=[]
  for profile in g['profiles']:
   item=g['frames'][f'{profile}-{tic}'];p=(native/item['file']).read_bytes();assert sha(p)==item['sha256'];expected.append(p);assert pal==(native/item['paletteFile']).read_bytes()
  virtual={s['y']*320+s['x'] for s in f['virtualSamples']}
  for s in f['virtualSamples']:report['virtualZoneUses' if s['provenance']==4 else 'virtualOwnerUses']+=1
  whole=pixels==expected[0];report['wholeNativeFramesEqual']+=whole
  checked=0
  for i in range(64000):
   if i not in virtual and all(p[i]==expected[0][i] for p in expected):assert pixels[i]==expected[0][i],(m,tic,i,'common-native pixel mismatch');checked+=1
  report['commonNativePixelsChecked']+=checked;report['gameplay'][str(tic)]=dict(frameId=f['frameId'],wholeO2Equal=whole,commonPixels=checked,virtualUses=len(f['virtualSamples']))
counts=collections.Counter(f['kind'] for f in r['frames']);assert sum(counts.values())==len(r['frames']);assert [f['frameId'] for f in r['frames']]==list(range(1,len(r['frames'])+1));assert r['nativeGameplayComparisons']==r['gameplayTics']+1
if not a.partial:
 assert r['pass'] and r['gameplayTics']==n['executedTics'] and r['demoTics']==(n['executedTics'] if r['identity'].get('presentationPolicy') else len(t['commands'])) and r['gameplayCaptures']==n['executedTics'];assert len(report['gameplay'])==n['executedTics']
 if r['identity'].get('presentationPolicy'):
  assert r['originalTapeConsumedTics']==n['executedTics'] and r['originalTapePreservedTotalTics']==len(t['commands'])
  recipe=[] if m==8 else [0,1]+[0]*104+[1,0,1]+[0]*9
  actual=[x['buttons'] for x in r['postExitInputs']]
  assert all(x['rawHex']==f'000000{b:02x}' for x,b in zip(r['postExitInputs'],actual))
  assert actual==recipe if m!=8 else all(b==0 for b in actual)
 ui=json.loads((out/'ui-verification.json').read_text());assert ui['pass_'];report['nativeUIFrames']=ui['nativePresentationFrames'];report['nativeExactAllPresentationFrames']=len({x['frameId'] for x in ui['frames']}|{x['frameId'] for x in report['gameplay'].values() if x['wholeO2Equal']});report['finalFrameNativePixelDifferences']=0;report['nativeUIpixelComparisons']=ui['nativePresentationPixels']
 media=json.loads((out/'media.json').read_text());assert media['pass_'] and sha(Path(media['path']).read_bytes())==media['sha256'];assert media['frames']==len(r['frames'])
report['pass_']=True;(out/('partial-verification.json' if a.partial else 'verification.json')).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='gameplay'}))
