#!/usr/bin/env python3
"""Create an observation-only production save/load MSIZE-marker clone."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
path=ROOT/'src/evm/Doom.sol';original=path.read_text();source=original
assert 'DoomSaveMemoryProbe' not in source and 'memorySize()' not in source
source=source.replace('contract Doom is','contract DoomSaveMemoryProbe is',1)
source=source.replace('from "../doom/','from "../../../../src/doom/').replace('from "../support/','from "../../../../src/support/').replace('from "./','from "../../../../src/evm/')
for operation,fn in [(1,'_saveGame'),(2,'_loadGame')]:
    start=source.index('function '+fn+'(');opening=source.index('{',start);end=opening+1;depth=1
    while depth:
        if source[end]=='{':depth+=1
        elif source[end]=='}':depth-=1
        end+=1
    source=source[:end-1]+f'        emit MemoryBoundary({operation}, memorySize());\n    '+source[end-1:]
end=source.rfind('}')
source=source[:end]+'''    event MemoryBoundary(uint8 operation, uint256 highWaterBytes);
    function memorySize() private view returns(uint256) { return gasleft(); }
'''+source[end:]
out=ROOT/'artifacts/local/death-save-main/memory';out.mkdir(parents=True,exist_ok=True)
(out/'DoomSaveMemoryProbe.sol').write_text(source)
sha=lambda b:hashlib.sha256(b).hexdigest()
(out/'source.json').write_text(json.dumps({'kind':__doc__,'originalSourceSha256':sha(original.encode()),
    'cloneSourceSha256':sha(source.encode()),'changes':['Contract name/import paths only; end-of-save/load observer events and private GAS marker.'],
    'scope':'Current call-frame MSIZE through observer boundary, after production Frame encoding; excludes following observer encoding and separate precompile frames.'},indent=2)+'\n')
print(out/'DoomSaveMemoryProbe.sol')
