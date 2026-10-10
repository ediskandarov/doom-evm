#!/usr/bin/env python3
"""Generate an ignored error-only renderer clone, retaining every rejecting guard."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[3]
dest = ROOT / 'artifacts/local/speedrun-tic52/diagnostic/src'
dest.mkdir(parents=True, exist_ok=True)
shutil.copytree(ROOT / 'src', dest, dirs_exist_ok=True)
p = dest / 'doom/r_state.sol'
s = p.read_text().replace('pragma solidity 0.8.37;', 'pragma solidity 0.8.37;\nimport {ZoneState} from "./z_zone_types.sol";')
s = s.replace('struct DrawColumn {', 'struct DrawColumn {\n    uint32 diagnosticBlock;\n    uint32 diagnosticBase;\n    uint32 diagnosticSize;\n    uint32 diagnosticZone;\n    uint32 diagnosticOwner;\n    ZoneState diagnosticLedger;')
p.write_text(s)
p = dest / 'doom/z_zone_backing.sol'
s = p.read_text().replace('clear(dc);', '''clear(dc);
        dc.diagnosticBlock = sourceBlock;
        if (sourceBlock != 0 && sourceBlock < resources.nativeZone.blockCount) {
            ZoneBlock memory b = resources.nativeZone.blocks[sourceBlock];
            dc.diagnosticBase = b.offset;
            dc.diagnosticSize = b.size;
            dc.diagnosticZone = resources.nativeZone.byteLength;
            dc.diagnosticOwner = b.owner;
            dc.diagnosticLedger = resources.nativeZone;
        }''', 1)
p.write_text(s)
p = dest / 'doom/r_draw.sol'
s = p.read_text().replace('error DrawBounds();', '''error DrawBounds();
    error DiagnosticGuard(uint32 sourceLine);
    error DiagnosticSample(int256 index, uint256 logicalLength, uint32 sourceOffset,
        uint256 tailLength, uint256 knownLength, bytes1 known, bytes32 sourceHash,
        int32 x, int32 yl, int32 yh, uint256 row, uint32 blockId, uint32 blockBase,
        uint32 blockSize, uint32 zoneLength, uint32 owner, bytes ledger);''')
needle = ') revert DrawBounds();\n                color = uint8(dc.sourceTail[tailIndex]);'
assert s.count(needle) == 1
s = s.replace(needle, ''') revert DiagnosticSample(index, dc.source.length, dc.sourceOffset,
                    dc.sourceTail.length, dc.sourceTailKnown.length,
                    tailIndex < dc.sourceTailKnown.length ? dc.sourceTailKnown[tailIndex] : bytes1(0xff),
                    sha256(dc.source), dc.x, dc.yl, dc.yh, i, dc.diagnosticBlock,
                    dc.diagnosticBase, dc.diagnosticSize, dc.diagnosticZone,
                    dc.diagnosticOwner, abi.encode(dc.diagnosticLedger));
                color = uint8(dc.sourceTail[tailIndex]);''')
# Other failures identify their original guard line. Added fields affect only
# diagnostic memory/ABI/gas, so none of its cost metrics are production claims.
original = (ROOT / 'src/doom/r_draw.sol').read_text().splitlines()
lines = [i + 1 for i, line in enumerate(original) if 'revert DrawBounds();' in line]
lines.remove(60)
for line in lines:
    s = s.replace('revert DrawBounds();', f'revert DiagnosticGuard({line});', 1)
assert 'revert DrawBounds();' not in s
p.write_text(s)
files = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in dest.rglob('*.sol')}
(dest.parent / 'manifest.json').write_text(json.dumps(dict(
    scope='Error-only test clone; all production guards retained; extra diagnostic allocations change gas',
    files=files), indent=2) + '\n')
print(dest / 'support/SpeedrunVideoProbe.sol')
