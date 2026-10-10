import subprocess,json,hashlib,tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[3];out=Path(__file__).resolve().parent
git=lambda *a:subprocess.check_output(["git",*a],cwd=root)
sha=lambda b:hashlib.sha256(b).hexdigest()
r=json.loads((out/"preflight.json").read_text());result={"pass":True,"features":{},"scope":"Git blob/source/evidence integrity and archived-result consistency; no historical tests rerun."}
for name,b in r["branches"].items():
 subprocess.run(["git","merge-base","--is-ancestor",b["tip"],"HEAD"],cwd=root,check=True)
 for path,blob in b["sourceBlobs"].items():assert git("hash-object",path).decode().strip()==blob,path
 result["features"][name]={"tip":b["tip"],"preservedFiles":len(b["sourceBlobs"])}
menu=json.loads((root/"artifacts/phase4/menu/verification.json").read_text())
assert subprocess.check_output(["git","-C",str(root/"original/DOOM"),"rev-parse","HEAD"],text=True).strip()=="a77dfb96cb91780ca334d0d4cfd86957558007e0"
for path,h in menu["sourceEvidenceSha256"].items():
 data=(root/path).read_bytes() if path.startswith("original/DOOM/") else git("show","fa67651d:"+path)
 assert sha(data)==h,path
result["menuHistoricalBindings"]=len(menu["sourceEvidenceSha256"]);result["menuInheritedCounts"]=menu["counts"]
checkpoint=json.loads((root/"artifacts/virtual-pointer/checkpoint.json").read_text())
archive=root/"artifacts/virtual-pointer/evidence.tar.gz"
assert sha(archive.read_bytes())==checkpoint["evidenceArchiveSha256"]
with tarfile.open(archive) as t:
 assert set(t.getnames())==set(checkpoint["evidenceFiles"])
 for path,h in checkpoint["evidenceFiles"].items():assert sha(t.extractfile(path).read())==h,path
 legacy=json.load(t.extractfile("legacy-sampled/evm.json"))
 previous=json.loads((root/"artifacts/speedrun-e1m1-video/frame-manifest.json").read_text())
 assert [(f["tic"],f["indexed8Sha256"]) for f in legacy["frames"]]==[(f["tic"],f["indexed8Sha256"]) for f in previous["frames"]]
 for policy in ["strict","legacy","episode"]:
  report=json.load(t.extractfile("disabled-"+policy+"/evm.json"))
  failure=report["renderFailure"]
  assert not report["pass"] and failure["tic"]==52 and failure["rollback"]["allSavedFieldsUnchanged"] and failure["rollback"]["frameCounterUnchanged"] and failure["rollback"]["noLogs"]
result["virtualArchivedFiles"]=len(checkpoint["evidenceFiles"]);result["preservedSampledHashes"]=len(legacy["frames"])
result["disabledTic52Policies"]=["strict","legacy","episode"]
for path in ["src/doom/r_draw.sol","src/doom/z_zone.sol","src/evm/EpisodeStartup.sol","src/evm/EpisodeRuntime.sol","src/evm/FrameProtocol.sol","src/evm/InputProtocol.sol","foundry.toml","execution-budget.json","artifacts/speedrun-e1m1/tape.json","artifacts/speedrun-e1m1/e1m1-easy.lmp"]:
 assert git("show",r["baseline"]+":"+path)==(root/path).read_bytes(),path
prod=(root/"src/evm/Doom.sol").read_text();probe=(root/"src/support/SpeedrunVideoProbe.sol").read_text();cli=(root/"tools/reference/speedrun/evm-video.mjs").read_text()
assert "experimentalVirtualPointers" not in prod
assert "initializeProfile(1);" in probe and "experimentalVirtualPointers = profile == 3;" in probe
assert "option('--memory-profile', 'legacy')" in cli
result["sourceDefaultPolicyChecks"]=True
(out/"integrity-result.json").write_text(json.dumps(result,indent=2)+"\n");print(json.dumps(result))
