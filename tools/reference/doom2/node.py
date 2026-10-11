#!/usr/bin/env python3
"""Run affected browser installer/menu/input/Frame tests and lifecycle cleanup."""
from pathlib import Path
import datetime,hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[3]
paths=sorted(str(p.relative_to(ROOT)) for p in (ROOT/'web').glob('*.test.mjs'))+['tools/transport/protocol.test.mjs','tools/transport/palette.test.mjs','tools/transport/ui-palette.test.mjs','tools/transport/lifecycle.test.mjs']
overrides={p:p.read_bytes() if p.exists() else None for p in [ROOT/'web/config.local.json',ROOT/'web/palette.local.json']};
cmd=['node','--test',*paths];start=datetime.datetime.now(datetime.timezone.utc).isoformat();t=time.perf_counter();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True);
for p,before in overrides.items():
 if before is None:p.unlink(missing_ok=True)
 else:p.write_bytes(before)
b=(r.stdout+r.stderr).encode();(ROOT/'artifacts/doom2/node.log').write_bytes(b);(ROOT/'artifacts/doom2/node.json').write_text(json.dumps(dict(pass_=r.returncode==0,startUTC=start,endUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),seconds=time.perf_counter()-t,command=cmd,logSHA256=hashlib.sha256(b).hexdigest()),indent=2)+'\n');print(b.decode()[-2500:]);raise SystemExit(r.returncode)
