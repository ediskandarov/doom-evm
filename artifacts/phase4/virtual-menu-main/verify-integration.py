import json,hashlib,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[3]
folder=Path(__file__).resolve().parent
r=json.loads((folder/"integration.json").read_text())
sha=lambda data:hashlib.sha256(data).hexdigest()
for p,h in r["evidenceSha256"].items():assert sha((root/p).read_bytes())==h,p
assert sha((root/"docs/PHASE4-PLAN.md").read_bytes())==r["ledgerSha256"]
for branch,data in r["sourceTips"].items():
 subprocess.run(["git","merge-base","--is-ancestor",data,"HEAD"],cwd=root,check=True)
print("PASS integration evidence hashes, ledger and source ancestry",len(r["evidenceSha256"]))
