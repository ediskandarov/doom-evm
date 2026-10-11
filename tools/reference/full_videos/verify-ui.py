#!/usr/bin/env python3
"""Compare original tail/hold UI and actual transitions against independent C pixels/palettes."""
import argparse,json,hashlib,subprocess,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).parent
ap=argparse.ArgumentParser();ap.add_argument('recording',type=Path);ap.add_argument('--partial',action='store_true');a=ap.parse_args();out=a.recording.resolve();r=json.loads((out/'recording.json').read_text());m=r['identity']['map'];native=ROOT/f'artifacts/local/full-videos/E1M{m}/native-ui';n=json.loads((native/'manifest.json').read_text());assert n['pass_'];assert set(n['profiles'])=={'O2','O0','sanitize'}
sha=lambda b:hashlib.sha256(b).hexdigest();ui=[f for f in r['frames'] if f['kind'] in [1,3,4] or f['kind']==2 and f['demoTic']!=1];reference=n['frames'];assert len(ui)==len(reference) if not a.partial else len(ui)<=len(reference)
checked=[]
for actual,expected in zip(ui,reference):
 for key in ['kind','demoTic','gameplayTic','rng','stage','count']:assert actual[key]==expected[key],(key,actual,expected)
 pixels=(out/actual['file']).read_bytes();nativePixels=(native/expected['file']).read_bytes();assert sha(nativePixels)==expected['sha256'];differences=sum(x!=y for x,y in zip(pixels,nativePixels));assert differences==0,('UI/melt pixel mismatch',actual['frameId'],differences)
 pal=(out/actual['paletteFile']).read_bytes();assert pal==(native/expected['paletteFile']).read_bytes()
 checked.append(dict(frameId=actual['frameId'],nativeFile=expected['file'],nativeSha256=expected['sha256'],pixelDifferences=0))
entry=[f for f in r['frames'] if f['kind']==2 and f['demoTic']==1];assert entry
entryRef=ROOT/f'artifacts/local/full-videos/E1M{m}/native-entry-wipe'
if not (entryRef/'manifest.json').exists():
 title=next(x for x in reference if x['kind']==1)
 subprocess.run(['python3',HERE/'wipe-frames.py','--start',native/title['file'],'--end',ROOT/f'artifacts/local/full-videos/E1M{m}/native/gameplay-000001.indexed8','--seed','1','--output',entryRef],check=True)
w=json.loads((entryRef/'manifest.json').read_text());assert len(entry)==len(w['frames'])
for actual,expected in zip(entry,w['frames']):
 assert actual['rng']==65 # ST tic1, then original 320 wipe random calls, modulo256
 pixels=(out/actual['file']).read_bytes();p=(entryRef/expected['file']).read_bytes();assert sha(p)==expected['sha256'];assert pixels==p,('entry melt',actual['frameId']);checked.append(dict(frameId=actual['frameId'],nativeFile=str(entryRef/expected['file']),nativeSha256=expected['sha256'],pixelDifferences=0))
# Completion statistics are emitted from EVM G_DoCompleted/WI_Start, never supplied by host.
base=ROOT/f'artifacts/local/ultimate-speedruns/E1M{m}'
if m==8:base=base/'alternatives/sedlo-046'
info=json.loads((base/'native-result.json').read_text());stats=[]
for f in r['frames']:
 if f['kind']!=3:continue
 b=bytes.fromhex(f['statsHex']);words=[int.from_bytes(b[i:i+32],'big',signed=True) for i in range(0,len(b),32)];assert len(words)==50
 p=info['finalPlayer'];assert words[0]==0 and words[2]==m-1 and words[3]==(8 if info['profiles'][0]['exitEvents'][0][3] else 3 if m==9 else m)
 assert words[4:7]==[max(1,p['totalKills']),max(1,p['totalItems']),max(1,p['totalSecrets'])]
 assert words[11:15]==[p['killcount'],p['itemcount'],p['secretcount'],p['leveltime']]
 assert words[8]==35*[0,30,75,120,90,165,180,180,30,165][m]
 if m==9:assert words[1]==1
 stats=words;break
if not a.partial:assert m==8 or stats
report=dict(pass_=True,map=m,nativePresentationFrames=len(checked),nativePresentationPixels=len(checked)*64000,allPixelsAndPalettesExact=True,sourceProfile='Original C borrowed immutable UI resources, existing LP64 initialized zone, one-tic blocking display clock; genuine original-input exit; zero-input original WI/F hold.',originalTailAndContinuationFrames=len(ui),entryWipeFrames=len(entry),authoritativeStatisticsABIWords=stats,nativeManifestSHA256=sha((native/'manifest.json').read_bytes()),entryMeltManifestSHA256=sha((entryRef/'manifest.json').read_bytes()),frames=checked)
(out/('partial-ui-verification.json' if a.partial else 'ui-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='frames'}))
