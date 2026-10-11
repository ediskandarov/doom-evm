#!/usr/bin/env python3
"""Prepare authenticated, ignored code images for the scoped retail Forge tests."""
from pathlib import Path
import hashlib, subprocess
ROOT=Path(__file__).resolve().parents[2]
subprocess.run(['python3','tools/reference/phase2_data/prepare_chunks.py'],cwd=ROOT,check=True)
source=ROOT/'artifacts/local/ultimate-speedruns/wad'
blob=(source/'resources.bin').read_bytes();directory=(source/'directory.bin').read_bytes()
assert len(blob)==12370751 and len(directory)==2306*16
assert hashlib.sha256(directory).hexdigest()=='6c5e07c8ea410c014b2dc57959c214bae0783c78668fb119d32c6a5514d33287'
chunks=[b'\0'+blob[i:i+16384] for i in range(0,len(blob),16384)]
assert len(chunks)==756 and len(chunks[-1])==832
assert hashlib.sha256(b''.join(hashlib.sha256(c).digest() for c in chunks)).hexdigest()=='0ab133e15d4bcfe400cf7106b8dc1d26ca62f912ca1314eac69a6c0e2bdc8c04'
out=ROOT/'artifacts/local/wad/ultimate';out.mkdir(parents=True,exist_ok=True)
for i,chunk in enumerate(chunks):(out/f'{i}.bin').write_bytes(chunk)
(out/'directory.bin').write_bytes(directory)
print('756 exact Ultimate code images prepared; commercial bytes remain ignored')
