#!/usr/bin/env python3
"""Record region gas and allocator high-water marks without retaining large Forge traces."""
import hashlib,json,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
cmd=[str(ROOT/'.toolchain/bin/forge'),'test','--match-contract','RPlanesTest','--match-test','testOriginalPlaneAngle','-vvvv']
p=subprocess.Popen(cmd,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
rows=[]
for line in p.stdout:
 if 'emit PlaneMetrics(' in line:
  pairs=re.findall(r'(\w+): (\d+)',line);row={k:int(v) for k,v in pairs};rows.append(row)
 if '[FAIL' in line:print(line,end='')
assert p.wait()==0 and len(rows)==8
rows.sort(key=lambda r:r['angle'])
files=['src/doom/r_plane.sol','test/unit/r_plane.t.sol','src/doom/tables.sol','src/doom/r_draw.sol','src/doom/r_segs.sol','src/evm/DoomScene.sol']
report={'command':cmd[1:],'sourceSha256':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in files},'memoryMeaning':'mload(0x40) allocator positions, not MSIZE; excludes cheatcode read buffers after renderer and external chunk deployment/setup. Gas regions include current memory expansion.','rows':rows}
(ROOT/'test/fixtures/phase2_planes/costs.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(rows,indent=2))
