#!/usr/bin/env python3
"""Prepare an isolated observation-only presentation clone without touching shared sources."""
import subprocess,json,hashlib,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=ROOT/'artifacts/local/full-videos/observer');a=ap.parse_args();out=a.output.resolve()
subprocess.run(['python3',str(ROOT/'tools/reference/ultimate_speedruns/observer-owner.py'),'--output',str(out)],check=True,cwd=ROOT)
p=out/'src/support/FullSpeedrunProbe.sol';s=p.read_text()
for before,after in [('error InvalidReplay();','error InvalidReplay();\n    event VirtualSamples(uint32 indexed tic,bytes samples);'),('// Observer insertion point: all generated provenance is emitted here.','emit VirtualSamples(tic,c.resources.virtualSamples);')]:
 assert s.count(before)==1;s=s.replace(before,after)
p.write_text(s)
m=json.loads((out/'manifest.json').read_text());m['presentationCloneSha256']=hashlib.sha256(s.encode()).hexdigest();m['fullPresentationSources']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (out/'src').rglob('*.sol')};(out/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
print('Prepared presentation clone',p)
