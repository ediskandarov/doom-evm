#!/usr/bin/env python3
"""Generate a test-only provenance observer. Keep arithmetic and all draw guards."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[3]
DEST=ROOT/'artifacts/local/virtual-pointer/observer/src'
DEST.mkdir(parents=True,exist_ok=True)
shutil.copytree(ROOT/'src',DEST,dirs_exist_ok=True)
changes={}


def edit(name, replacements):
    p=DEST/name
    s=p.read_text()
    original=hashlib.sha256(s.encode()).hexdigest()
    for before,after in replacements:
        assert s.count(before)==1,(name,before,s.count(before))
        s=s.replace(before,after)
    p.write_text(s)
    changes[name]=dict(originalSha256=original,observerSha256=hashlib.sha256(s.encode()).hexdigest())


edit('doom/r_state.sol',[
 ('pragma solidity 0.8.37;', 'pragma solidity 0.8.37;\nimport {ZoneState} from "./z_zone_types.sol";'),
 ('struct RenderState {','struct RenderState {\n    bytes virtualSamples;'),
 ('struct DrawColumn {','struct DrawColumn {\n    bytes tailProvenance;\n    uint32 sourceBlock;\n    ZoneState sampleZone;')])
edit('doom/r_data_types.sol',[
 ('struct RenderResources {','struct RenderResources {\n    bytes virtualSamples;')])
edit('doom/z_zone_backing.sol',[
 ('clear(dc);','''clear(dc);
        dc.sourceBlock = sourceBlock;
        dc.sampleZone = resources.nativeZone;
        dc.tailProvenance = new bytes(0);'''),
 ('''(dc.sourceTail, dc.sourceTailKnown) =
            tail(resources, sourceBlock, uint32(dc.source.length), uint32(required));''',
 '''(dc.sourceTail, dc.tailProvenance) =
            tailWithProvenance(resources, sourceBlock, uint32(dc.source.length), uint32(required));
        dc.sourceTailKnown = new bytes(dc.tailProvenance.length);
        for (uint256 i; i < dc.tailProvenance.length; ++i) {
            dc.sourceTailKnown[i] = dc.tailProvenance[i] == 0 ? bytes1(0) : bytes1(0x01);
        }''')])
edit('doom/r_draw.sol',[
 ('library R_Draw {','''library R_Draw {
    // Observation only. Record each actual provenance4 sample after its original guard.
    function recordVirtual(RenderState memory rs, DrawColumn memory dc, uint256 index,
        uint256 dest, uint8 color, bool translated) private pure {
        uint256 physical = uint256(dc.sampleZone.blocks[dc.sourceBlock].offset) + 40 + index;
        uint32 id = dc.sourceBlock;
        while (physical >= uint256(dc.sampleZone.blocks[id].offset) + dc.sampleZone.blocks[id].size) {
            id = dc.sampleZone.blocks[id].next;
        }
        uint32 relative = uint32(physical - dc.sampleZone.blocks[id].offset);
        uint32 field = relative < 16 ? 8 : (relative < 32 ? 24 : 32);
        uint32 target = field == 24 ? dc.sampleZone.blocks[id].next : dc.sampleZone.blocks[id].prev;
        uint64 pointer;
        if (field == 8) {
            pointer = dc.sampleZone.blocks[id].allocated ? 2 : 0;
        } else {
            pointer = 0x0000001000000000 + uint64(dc.sampleZone.blocks[target].offset);
        }
        rs.virtualSamples = bytes.concat(rs.virtualSamples, abi.encode(
            uint256(dc.sourceBlock), physical, uint256(id), uint256(dc.sampleZone.blocks[id].offset),
            uint256(relative), uint256(field), uint256(field == 8 ? 0 : dc.sampleZone.blocks[target].offset),
            uint256(pointer), uint256(color), uint256(uint8(dc.colormap[translated ? uint8(dc.translation[color]) : color])),
            dest % 320, dest / 320, index, uint256(dc.source.length), uint256(dc.sourceOffset), uint256(4)));
    }'''),
 ('color = uint8(dc.sourceTail[tailIndex]);','''color = uint8(dc.sourceTail[tailIndex]);
                if (dc.tailProvenance[tailIndex] == 0x04) {
                    recordVirtual(rs, dc, uint256(index), dest, color, translated);
                }''')])
edit('evm/DoomGame.sol',[
 ('pixels = r.rs.framebuffer;', 'c.resources.virtualSamples = r.rs.virtualSamples;\n        pixels = r.rs.framebuffer;')])
edit('support/SpeedrunVideoProbe.sol',[
 ('error InvalidReplay();','error InvalidReplay();\n    event VirtualSamples(uint32 indexed tic, bytes samples);'),
 ('emit Frame(++frameId, tic, 320, 200, pixels);','emit VirtualSamples(tic, c.resources.virtualSamples);\n        emit Frame(++frameId, tic, 320, 200, pixels);')])
report=dict(scope='Generated observation-only clone; unchanged draw arithmetic, guards, allocator, resources, profile.',
            changes=changes,files={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                                   for p in DEST.rglob('*.sol')})
(DEST.parent/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print(DEST/'support/SpeedrunVideoProbe.sol')
