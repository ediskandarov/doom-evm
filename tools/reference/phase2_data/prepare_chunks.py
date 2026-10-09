#!/usr/bin/env python3
"""Split the hash-pinned Phase1 resource blob into test-only code-image files (not tracked)."""
import pathlib, hashlib
ROOT=pathlib.Path(__file__).resolve().parents[3]
p=ROOT/'artifacts/local/wad/resources.bin';blob=p.read_bytes()
assert hashlib.sha256(blob).hexdigest()=='0a07ab5de33592142c3427d29e8f2eaf25d0e4fa21e03ac9c9b0fb5d77531d16'
d=p.parent/'phase2-chunks';d.mkdir(exist_ok=True)
for i in range(0,len(blob),16384):(d/f'{i//16384}.bin').write_bytes(b'\0'+blob[i:i+16384])
print(f'{(len(blob)+16383)//16384} pinned test chunks prepared')
