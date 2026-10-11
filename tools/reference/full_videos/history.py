#!/usr/bin/env python3
"""Read-only original-input, historical media/frame/provenance preservation audit."""
import json,hashlib,zipfile,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();pre=json.loads((ROOT/'artifacts/local/full-videos/preflight.json').read_text());checked=[]
for f in pre['files']:
 if 'historical' in f:
  p=Path(f['historical']);assert p.stat().st_size==f['size'] and sha(p.read_bytes())==f['sha256'];checked.append(dict(path=str(p),sha256=f['sha256'],bytes=f['size']))
 else:
  p=ROOT/f['destination'];assert sha(p.read_bytes())==f['sha256'];assert sha(Path(f['source']).read_bytes())==f['sha256']
inputs=[];frameCount=0;virtualUses=0
for m in range(1,10):
 relative=Path(f'E1M{m}')/('alternatives/sedlo-046' if m==8 else '')
 committed=ROOT/'artifacts/ultimate-speedruns'/relative;metadata=json.loads((committed/'source.json').read_text());archive=committed/'original.zip';assert sha(archive.read_bytes())==metadata['archiveSha256']
 with zipfile.ZipFile(archive) as z:
  assert not any(name.lower().endswith('.wad') for name in z.namelist());data=z.read(metadata['originalName']);assert sha(data)==metadata['demoSha256']
 local=ROOT/'artifacts/local/ultimate-speedruns'/relative;assert (local/'source-download').read_bytes()==data
 old=Path('/Users/eduard/sandbox/doom-evm-ultimate-speedruns/artifacts/local/ultimate-speedruns')/relative/'owner-v1/full-rate';manifest=json.loads((old/'frame-manifest.json').read_text())
 for f in manifest['frames']:
  p=old/f['file'];assert sha(p.read_bytes())==f['indexed8Sha256'];frameCount+=1;virtualUses+=len(f['virtualSamples'])
 inputs.append(dict(map=m,originalName=metadata['originalName'],archiveSHA256=sha(archive.read_bytes()),inputSHA256=sha(data),historicalFrames=len(manifest['frames']),historicalManifestSHA256=sha((old/'frame-manifest.json').read_bytes())))
assert frameCount==14475
out=ROOT/'artifacts/full-videos';out.mkdir(exist_ok=True);report=dict(pass_=True,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Read-only archive/input/canonical source copy and all nine owner-v1 historical indexed frames, manifests, provenance metadata and preflight-hashed MP4s. No historical file was rewritten.',historicalIndexedFramesVerified=frameCount,historicalVirtualUses=virtualUses,preservedMediaAndManifests=checked,originalInputs=inputs)
(out/'historical-preservation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(pass_=True,historicalFrames=frameCount,historicalVirtualUses=virtualUses,inputs=len(inputs))))
