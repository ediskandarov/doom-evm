#!/usr/bin/env python3
"""Reuse the preserved read-only tic52 sampler with goal-owned output paths."""
import hashlib
import json
from pathlib import Path
import runpy
import sys

ROOT=Path(__file__).resolve().parents[3]
source=ROOT/'tools/reference/speedrun/native-sample.py'
original=source.read_text()
assert original.count("base = ROOT / 'artifacts/local/speedrun-tic52'")==1
assert original.count("'native-frames-recheck'")==1
text=original.replace("base = ROOT / 'artifacts/local/speedrun-tic52'",
                      "base = ROOT / 'artifacts/local/virtual-pointer'")
text=text.replace("'native-frames-recheck'", "'native-frames'")
out=ROOT/'artifacts/local/virtual-pointer/native-sampler.py'
out.write_text(text)
sys.path.insert(0,str(source.parent))
runpy.run_path(str(out),run_name='__main__')
result=out.parent/'native-sample/sample.json'
report=json.loads(result.read_text())
report['samplerIdentity']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in [Path(__file__),source,out]}
result.write_text(json.dumps(report,indent=2)+'\n')
