#!/usr/bin/env python3
"""Reacquire the two selected DSDA archives; pin original demo and archive hashes."""
import hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest()
for map_ in (1,7):
 source=json.loads((ROOT/f'artifacts/doom2/MAP{map_:02d}/source.json').read_text());out=ROOT/f'artifacts/local/doom2/MAP{map_:02d}';out.mkdir(parents=True,exist_ok=True)
 archive=out/'original.zip'
 if not archive.exists():subprocess.run(['curl','--connect-timeout','10','--max-time','30','-fsSL',source['downloadUrl'],'-o',str(archive)],check=True)
 assert sha(archive.read_bytes())==source['archiveSha256']
 with zipfile.ZipFile(archive) as z:
  assert not any(n.lower().endswith('.wad') for n in z.namelist())
  demo=z.read(source['originalName']);assert sha(demo)==source['demoSha256']
 (out/'source-download').write_bytes(demo);(out/'source.json').write_text(json.dumps(source,indent=2)+'\n');print('Pinned authentic DSDA',source['map'],source['originalName'])
