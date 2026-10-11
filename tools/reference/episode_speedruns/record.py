#!/usr/bin/env python3
"""Independent map recording coordinator; preserve completed outputs and resume."""
import argparse,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('map',choices=[f'E1M{i}' for i in range(1,10)])
    ap.add_argument('--port',type=int,default=18640);ap.add_argument('--resume',action='store_true');ap.add_argument('--encode-only',action='store_true');ap.add_argument('--checkpoint-every',type=int,default=250)
    a=ap.parse_args();base=ROOT/'artifacts/local/episode-speedruns'/a.map;recording=base/'full-rate';recording.mkdir(parents=True,exist_ok=True)
    lock=recording/'.recording.lock'
    try:fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
    except FileExistsError:raise SystemExit(f'Refusing existing goal-owned recording lock: {lock}; inspect its PID before recovering a stopped run.')
    os.write(fd,str(os.getpid()).encode());os.close(fd)
    try:
        n=json.loads((base/'native-result.json').read_text());assert n['exitReached'] and n['allProfilesExact'] and f"E1M{n['settings']['map']}"==a.map
        if not a.encode_only:
            if (recording/'evm.json').exists():
                r=json.loads((recording/'evm.json').read_text());assert not r['pass'],'Completed recording already exists; use --encode-only'
                assert a.resume,'Existing incomplete recording requires explicit --resume'
            command=['node',str(ROOT/'tools/reference/episode_speedruns/evm.mjs'),'--artifacts',str(base),'--output-prefix',str(recording/'evm'),'--port',str(a.port),'--checkpoint-every',str(a.checkpoint_every)]
            if a.resume:command.append('--resume')
            subprocess.run(command,cwd=ROOT,check=True)
        subprocess.run([sys.executable,str(ROOT/'tools/reference/episode_speedruns/encode.py'),str(recording)],cwd=ROOT,check=True)
        command=[sys.executable,str(ROOT/'tools/reference/episode_speedruns/verify.py'),str(base),str(recording)]
        if (base/'native-full/native-frames.json').exists():command+=['--native-frames',str(base/'native-full')]
        subprocess.run(command,cwd=ROOT,check=True)
    finally:lock.unlink()
if __name__=='__main__':main()
