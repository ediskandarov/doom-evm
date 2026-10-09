#!/usr/bin/env python3
"""Normalize source-backed original startup observations into comparison-only gold.

The original whole-host lifecycle builder owns native instrumentation/profile
checks. This tool does no allocation simulation: it checks/copies native records,
exports actual sizeof values and computes a compact operation-order digest.
DoomZoneStartup never consumes any file produced here as runtime input.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'test/fixtures/phase3_zone_startup'
NATIVE = ROOT / 'test/fixtures/phase3_zone_lifecycle'
UPSTREAM = 'a77dfb96cb91780ca334d0d4cfd86957558007e0'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encode(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def words(data):
    assert len(data) % 4 == 0
    return struct.unpack('>' + str(len(data) // 4) + 'I', data)


def generate(native):
    layout_bytes = (native / 'layout.json').read_bytes()
    layout = json.loads(layout_bytes)
    assert layout['upstreamCommit'] == UPSTREAM
    sizes = layout['layout']
    primitive = sizes['primitive']
    dimensions = [primitive['pointer'], primitive['int'], primitive['short'],
                  sizes['texture_t']['size'], sizes['texpatch_t']['size'],
                  sizes['spritedef_t']['size'], sizes['spriteframe_t']['size']]
    assert dimensions == [8, 4, 2, 28, 12, 16, 28], 'unreviewed native startup ABI'
    operations = (native / 'startup-operations.bin').read_bytes()
    rows = words(operations)
    count = rows[0]
    assert len(rows) == 1 + count * 7
    digest = bytes(32)
    histogram = {'malloc': 0, 'free': 0, 'changeTag': 0}
    for i in range(count):
        record = rows[1 + i * 7: 8 + i * 7]
        op, requested, tag, owner, offset, block_size, rover = record
        assert op in [1, 2, 3] and offset % 8 == 0 and rover % 8 == 0
        assert block_size >= sizes['memblock_t']['size']
        if op != 1:
            assert requested == 0
        if op == 2:
            assert tag == 0
        else:
            assert 0 <= tag <= 255
        histogram[{1: 'malloc', 2: 'free', 3: 'changeTag'}[op]] += 1
        digest = hashlib.sha256(digest + struct.pack('>7I', *record)).digest()
    headers = (native / 'startup-headers.bin').read_bytes()
    snapshot = words(headers)
    assert len(snapshot) >= 7
    byte_length, rover, cap_prev, cap_next, free_memory, blocks = snapshot[:6]
    assert byte_length == 64 * 1024 * 1024 and free_memory <= byte_length
    position = 6
    owners_seen = {}
    for _ in range(blocks):
        offset, size, allocated, owner, tag, known, identity, prev, next_ = snapshot[position:position + 9]
        assert offset % 8 == 0 and size >= 40 and allocated in [0, 1] and known in [0, 1]
        assert known or identity == 0, 'unknown header ID must stay masked'
        assert allocated or tag == 0, 'unknown free tag must stay masked'
        if owner != 0xffffffff:
            assert allocated and owner not in owners_seen
            owners_seen[owner] = offset + sizes['memblock_t']['size']
        position += 9
    owner_count = snapshot[position]
    position += 1
    assert len(snapshot) == position + owner_count
    for owner, pointer in enumerate(snapshot[position:]):
        assert pointer == owners_seen.get(owner, 0xffffffff), 'native owner marks/headers disagree'
    manifest_path = native / 'manifest.json'
    lifecycle = json.loads(manifest_path.read_bytes())
    assert lifecycle['upstreamCommit'] == UPSTREAM
    outputs = {
        'operations.bin': operations,
        'summary.bin': struct.pack('>I', count) + digest,
        'headers.bin': headers,
        'layout.bin': struct.pack('>7I', *dimensions),
    }
    manifest = {
        'schemaVersion': 1, 'upstreamCommit': UPSTREAM,
        'scope': 'Original R_Init followed by R_InitSprites, including R_InitData and R_InitTranslationTables; normalized outer zone calls and final live-header/owner state only. No native trace/header is a runtime input.',
        'operationCount': count, 'operations': histogram, 'operationDigest': digest.hex(),
        'digestSchema': 'SHA256 chaining: previous32zero initial +7BE32 [op1malloc/2free/3tag,requestSize,requestedTag,ownerNULLff,headerOffset,blockSize,roverAfter]; free header/size/owner captured before coalescing; nested purge events excluded.',
        'headerSchema': '6BE32 [byteLength,rover,capPrev,capNext,freeMemory,count];count*9 [offset,size,allocated,ownerNULLff,tagAllocatedElse0,idKnown,idKnownElse0,prev,next];ownerCount;ownerCount payloadOffsetsNULLff.',
        'layoutWordOrder': ['pointer', 'int', 'short', 'texture_t', 'texpatch_t', 'spritedef_t', 'spriteframe_t'],
        'nativeLayout': dimensions, 'liveBlocks': blocks, 'ownerCount': owner_count,
        'nativeLifecycleManifestSha256': sha(manifest_path.read_bytes()),
        'nativeLayoutManifestSha256': sha(layout_bytes),
        'nativeLifecycleProfiles': lifecycle['profiles'],
        'nativeLifecycleStatus': lifecycle['status'],
        'sourceObservationHashes': {name: sha((native / name).read_bytes()) for name in ['layout.json', 'startup-operations.bin', 'startup-headers.bin', 'manifest.json']},
        'converterSha256': sha(Path(__file__).read_bytes()),
        'limitations': ['Pointer/padding bytes are not modeled; original unset free-fragment IDs and tags remain masked.', 'This startup component does not certify map/gameplay allocations or rendering overread/payload bytes.', 'Native core purge/coalescing proof is separate; only source startup outer calls belong to this operation digest.'],
        'files': {name: sha(data) for name, data in sorted(outputs.items())},
    }
    outputs['manifest.json'] = encode(manifest)
    return outputs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', type=Path, default=NATIVE)
    parser.add_argument('--output', type=Path, default=OUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    outputs = generate(args.native)
    for name, data in outputs.items():
        path = args.output / name
        if args.check:
            assert path.read_bytes() == data, 'stale startup gold ' + name
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    manifest = json.loads(outputs['manifest.json'])
    print(f"PASS conversion of original startup observations ({manifest['nativeLifecycleStatus']}): {manifest['operationCount']} outer calls, {manifest['liveBlocks']} live headers, actual native sizeof exports")


if __name__ == '__main__':
    main()
