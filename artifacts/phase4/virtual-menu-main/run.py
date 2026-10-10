import sys,subprocess,time,json,datetime
from pathlib import Path
root=Path(__file__).resolve().parent
name=sys.argv[1];cmd=sys.argv[2:]
start=time.monotonic();record={"command":cmd,"startedUTC":datetime.datetime.now(datetime.timezone.utc).isoformat()}
with (root/(name+".log")).open("wb") as out:r=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT)
record.update(exitCode=r.returncode,elapsedSeconds=round(time.monotonic()-start,3),endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat())
(root/(name+".json")).write_text(json.dumps(record,indent=2)+"\n")
print(json.dumps(record));print((root/(name+".log")).read_text(errors="replace")[-6500:]);sys.exit(r.returncode)
