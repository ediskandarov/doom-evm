#!/usr/bin/env python3
"""Measure isolated BSP regions; stream verbose output without retaining resource byte traces."""
import argparse,hashlib,json,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=pathlib.Path,default=ROOT/'artifacts/local/phase2-bsp-costs.json');args=ap.parse_args()
 command=[str(ROOT/'.toolchain/bin/forge'),'test','--match-contract','RBspTest','--match-test','testOriginalE1M1Angle','-vvvv']
 proc=subprocess.Popen(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 rows=[]
 for line in proc.stdout:
  if 'emit BspMetrics(' in line:
   row={k:int(v) for k,v in re.findall(r'(angle|initGas|productionGas|instrumentedGas|allocatorAfter): (\d+)',line)}
   assert len(row)==5;rows.append(row)
 assert proc.wait()==0 and sorted(r['angle'] for r in rows)==list(range(8)),'BSP measurement test failed'
 rows.sort(key=lambda r:r['angle'])
 paths=['src/doom/r_bsp.sol','src/doom/r_main.sol','src/doom/r_data.sol','src/doom/r_plane.sol','src/doom/r_render_state.sol','src/doom/r_state.sol','src/doom/r_defs.sol','test/unit/r_bsp.t.sol','test/fixtures/phase2_bsp/InstrumentedR_BSP.sol','foundry.toml']
 result={'scope':'Isolated Foundry harness. initGas includes real lazy resource init/map/view setup. productionGas includes observation-only callbacks and plane construction, not wall drawing. instrumentedGas follows production in same call at a higher memory watermark. allocatorAfter is free-memory pointer after both runs and state/trace checks, not direct MSIZE.','sourceSha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},'cases':rows}
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(rows))
if __name__=='__main__':main()
