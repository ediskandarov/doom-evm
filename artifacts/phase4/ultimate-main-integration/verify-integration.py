from pathlib import Path
import json,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
r=json.loads((HERE/"integration.json").read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
for p,h in r["evidenceSha256"].items():assert sha((ROOT/p).read_bytes())==h,p
assert sha((ROOT/"docs/PHASE4-PLAN.md").read_bytes())==r["ledgerSha256"]
subprocess.run(["git","merge-base","--is-ancestor",r["sourceTip"],"HEAD"],cwd=ROOT,check=True)
pre=json.loads((HERE/"preflight.json").read_text())
for path,h in pre["sourceBlobs"].items():assert subprocess.check_output(["git","hash-object",path],cwd=ROOT,text=True).strip()==h,path
print("PASS integration hashes, ledger, source ancestry and256 delivered blobs",len(r["evidenceSha256"]))
