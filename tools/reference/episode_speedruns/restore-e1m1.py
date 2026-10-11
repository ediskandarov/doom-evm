#!/usr/bin/env python3
"""Restore inherited E1M1 media from hash-verified mined receipts, no new replay."""
import gzip,json,sys,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
from verify_video import sha,dynamic,FRAME_TOPIC
archive=ROOT/'artifacts/virtual-pointer/evidence.tar.gz';checkpoint=json.loads((archive.parent/'checkpoint.json').read_text())
assert sha(archive.read_bytes())==checkpoint['evidenceArchiveSha256']
out=ROOT/'artifacts/local/episode-speedruns/E1M1/inherited';(out/'frames').mkdir(parents=True,exist_ok=True)
with tarfile.open(archive) as t:
    def member(name):
        data=t.extractfile(name).read();assert sha(data)==checkpoint['evidenceFiles'][name];return data
    manifest=json.loads(member('full-rate/frame-manifest.json'))
    report=json.loads(member('full-rate/evm.json'))
    receipts=json.loads(gzip.decompress(member('full-rate/evm.capture-receipts.json.gz')))
    for c,f in zip(receipts,manifest['frames']):
        assert c['status']=='0x1' and c['transactionHash']==f['transactionHash']
        log=next(l for l in c['logs'] if l['topics'][0]==FRAME_TOPIC)
        assert log['address']==report['deployment']['address'] and int(log['topics'][2],16)==f['tic']
        pixels=dynamic(bytes.fromhex(log['data'][2:]),64);assert len(pixels)==64000 and sha(pixels)==f['indexed8Sha256']
        (out/f['file']).write_bytes(pixels)
assert manifest['pass'] and manifest['memoryProfile']=='virtual' and len(receipts)==len(manifest['frames'])==279
assert [f['tic'] for f in manifest['frames']]==list(range(1,280))
palette=bytes.fromhex(json.loads((ROOT/'artifacts/local/wad/palette.json').read_text())['rgbHex']);assert sha(palette)==manifest['authenticatedPaletteSha256']
(out/'palette.bin').write_bytes(palette);manifest['map']='E1M1';manifest.pop('media',None)
manifest['restoration']=dict(sourceArchive=str(archive.relative_to(ROOT)),archiveSha256=sha(archive.read_bytes()),inherited=True,noFreshEVMReplay=True)
(out/'frame-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(out)
