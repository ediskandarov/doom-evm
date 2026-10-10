#!/usr/bin/env python3
"""Stage authenticated archived input bytes; never overwrite an existing attempt."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];source=ROOT/'artifacts/ultimate-speedruns';dest=ROOT/'artifacts/local/ultimate-speedruns';count=0
sha=lambda b:hashlib.sha256(b).hexdigest()
for metadata in sorted(source.rglob('source.json')):
 s=json.loads(metadata.read_text());archive=metadata.parent/'original.zip';raw=archive.read_bytes();assert sha(raw)==s['archiveSha256']
 with zipfile.ZipFile(archive) as z:
  assert not any(n.lower().endswith('.wad') for n in z.namelist()),'Commercial WAD in input archive'
  demos=[n for n in z.namelist() if n.lower().endswith('.lmp')];assert demos==[s['originalName']]
  data=z.read(s['originalName']);assert sha(data)==s['demoSha256']
 assert s['IWADMD5']=='c4fe9fd920207691a9f493668e0a2083' and s['IWADSHA256']=='6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f'
 out=dest/metadata.parent.relative_to(source);out.mkdir(parents=True,exist_ok=True)
 for name,body in [('original.zip',raw),('source-download',data)]:
  p=out/name
  if p.exists():assert p.read_bytes()==body,'Existing input differs: '+str(p)
  else:p.write_bytes(body)
 p=out/'source.json'
 if p.exists():
  existing=json.loads(p.read_text())
  for key in ['demoSha256','archiveSha256','originalName','downloadUrl','IWADMD5','IWADSHA256']:assert existing[key]==s[key],'Existing provenance differs: '+str(p)
 else:p.write_bytes(metadata.read_bytes())
 count+=1
print(json.dumps(dict(authenticatedOriginalArchives=count,existingAttemptsPreserved=True,commercialPayloadsCopied=False)))
