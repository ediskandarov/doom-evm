from pathlib import Path
import json,hashlib,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
git=lambda *a:subprocess.check_output(["git",*a],cwd=ROOT)
pre=json.loads((OUT/"preflight.json").read_text())
assert git("rev-parse",pre["sourceBranch"]).decode().strip()==pre["sourceTip"]
for path,blob in pre["sourceBlobs"].items():assert git("hash-object",path).decode().strip()==blob,path
for c in pre["commits"]:subprocess.run(["git","merge-base","--is-ancestor",c.split()[0],"HEAD"],cwd=ROOT,check=True)
protected=["AGENTS.md","original","foundry.toml","execution-budget.json","src/doom/z_zone.sol","src/doom/z_zone_types.sol","src/doom/r_draw.sol","src/evm","web","test/fixtures","artifacts/phase4","artifacts/speedrun-e1m1","artifacts/speedrun-e1m1-video","artifacts/speedrun-tic52","artifacts/virtual-pointer"]
for path in protected:assert not git("diff",pre["baseline"],"HEAD","--",path),path
summary=json.loads((ROOT/"artifacts/ultimate-speedruns/owner-pointer/episode-summary.json").read_text())
assert summary["pass_"] and summary["completeMaps"]==9 and summary["EVMFrames"]==summary["gameplayTics"]==14475 and summary["snapshots"]==14484
assert summary["nativeVerdict"]=="RESTRICT" and not summary["RelaxedImplemented"]
assert summary["virtualZoneUses"]==20 and summary["virtualOwnerUses"]==18
rows=[];manifests=0
for row in summary["maps"]:
 report=ROOT/row["report"];assert sha(report.read_bytes())==row["reportSHA256"]
 r=json.loads(report.read_text());assert r["EVMGameplay"]["allSnapshotsExact"] and r["EVMGameplay"]["exit"]["reached"]
 assert r["frames"]["rendered"]==row["frames"]==row["tics"]
 assert r["media"]["SHA256"]==row["media"]["SHA256"]
 rows.append({"map":row["map"],"frames":row["frames"],"snapshots":row["snapshots"],"reportSHA256":row["reportSHA256"],"MP4SHA256":row["media"]["SHA256"]})
 manifest=report.parent/"evidence-manifest.json";assert manifest.is_file();manifests+=1
for path,h in json.loads((ROOT/"artifacts/ultimate-speedruns/owner-pointer/implementation-checkpoint.json").read_text())["sourceHashes"].items():assert sha((ROOT/path).read_bytes())==h,path
# Default activation and frame/pixel guards retain their original exact source blobs.
for path in ["src/support/SpeedrunVideoProbe.sol","src/doom/p_game_state.sol","src/doom/r_data_types.sol"]:assert git("show",pre["baseline"]+":"+path)==(ROOT/path).read_bytes(),path
for path in ["src/support/UltimateSpeedrunProbe.sol","src/support/EpisodeSpeedrunProbe.sol"]:
 s=(ROOT/path).read_text();assert "initializeMap(1, 1, 0, false);" in s and "experimentalVirtualPointers = profile == 3;" in s
for path in (ROOT/"src/evm").glob("*.sol"):assert "experimentalVirtualPointers = true" not in path.read_text(),path
result={"pass":True,"preservedSourceFiles":len(pre["sourceBlobs"]),"integratedCommits":len(pre["commits"]),"protectedUnchanged":protected,"episodeEvidence":{"maps":rows,"gameplayFrames":14475,"exactGameplaySnapshots":14484,"genuineCompletions":9,"virtualZoneUses":20,"virtualOwnerUses":18,"nativeVerdict":"RESTRICT","RelaxedImplemented":False,"committedEvidenceManifests":manifests},"scope":"Git/hash and metadata consistency only; accepted full frame/receipt/native/media gates inherited, not executed anew."}
(OUT/"integrity-result.json").write_text(json.dumps(result,indent=2)+"\n");print(json.dumps(result))
