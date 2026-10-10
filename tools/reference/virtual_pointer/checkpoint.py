#!/usr/bin/env python3
"""Preserve compact goal evidence and exact local artifact hashes after verification."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import time

ROOT=Path(__file__).resolve().parents[3]
LOCAL=ROOT/'artifacts/local/virtual-pointer'
OUT=ROOT/'artifacts/virtual-pointer'
sha=lambda b:hashlib.sha256(b).hexdigest()


def main():
    verification=json.loads((LOCAL/'verification.json').read_text())
    assert verification['pass_']
    video=json.loads((LOCAL/'full-rate/video-verification.json').read_text())
    assert video['pass_'] and video['standardEVMFrames']==279
    OUT.mkdir(parents=True,exist_ok=True)
    files=[]
    for directory in ['full-rate','observer-full-rate','legacy-sampled',
                      *['baseline-'+p for p in ['strict','legacy','episode']],
                      *['disabled-'+p for p in ['strict','legacy','episode']]]:
        files += [LOCAL/directory/'evm.json']
        files += list((LOCAL/directory).glob('evm.*-receipts.json.gz'))
    files += [LOCAL/'full-rate/frame-manifest.json',LOCAL/'full-rate/video-verification.json',
              LOCAL/'legacy-sampled/video-verification.json',LOCAL/'virtual-profile-manifest.json',
              LOCAL/'verification.json',LOCAL/'native-frames/native-frames.json',
              LOCAL/'native-sample/sample.json',LOCAL/'native-pointer/reference.json',
              LOCAL/'observer/manifest.json',LOCAL/'observer/src/doom/r_draw.sol',
              LOCAL/'out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json',
              LOCAL/'observer/out/SpeedrunVideoProbe.sol/SpeedrunVideoProbe.json']
    files += list(LOCAL.glob('*.log'))
    files += list((LOCAL/'native-pointer').glob('*.jsonl'))
    files += list((LOCAL/'native-frames').glob('build-*/*manifest.json'))
    files += list((LOCAL/'observer/src').rglob('*.sol'))
    files += list(LOCAL.glob('usage-snapshot.json'))
    files=sorted(set(files))
    # Deterministic archive metadata; retain all measurements inside the evidence.
    buffer=io.BytesIO()
    with tarfile.open(fileobj=buffer,mode='w') as archive:
        for p in files:
            data=p.read_bytes()
            info=tarfile.TarInfo(str(p.relative_to(LOCAL)))
            info.size=len(data);info.mode=0o644;info.mtime=0
            archive.addfile(info,io.BytesIO(data))
    packed=gzip.compress(buffer.getvalue(),mtime=0)
    (OUT/'evidence.tar.gz').write_bytes(packed)
    summary=dict(kind='experimental-deterministic-virtual-pointers',pass_=True,
        implementationCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        baseline='1e7033c149ddab6641be3116af3974d5ed585183',
        diagnosticDependency='001240b7b9f9dc794260dd75711ef1029b264357',
        recordedUTC=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
        verification=verification,video=video,
        evidenceArchiveSha256=sha(packed),
        evidenceFiles={str(p.relative_to(LOCAL)):sha(p.read_bytes()) for p in files},
        media={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [
            LOCAL/'full-rate/speedrun-e1m1.mp4',LOCAL/'full-rate/speedrun-e1m1-contact-sheet.png']},
        localFrames='artifacts/local/virtual-pointer/full-rate/frames',
        noMainMergeOrPush=True,completeHistoricalAcceptance=False)
    (OUT/'checkpoint.json').write_text(json.dumps(summary,indent=2)+'\n')
    (OUT/'virtual-profile-manifest.json').write_bytes((LOCAL/'virtual-profile-manifest.json').read_bytes())
    print(json.dumps(dict(pass_=True,files=len(files),archiveBytes=len(packed),archiveSha256=sha(packed))))


if __name__=='__main__':main()
