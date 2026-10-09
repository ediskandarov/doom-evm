#!/usr/bin/env python3
"""Cross-workstream identities, strict JSON shapes, table hashes and camera binding."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


schemas = module('phase0_schemas', ROOT / 'scripts/check-schemas.py')
oracle = module('c_reference', ROOT / 'tools/reference/reference.py')


def read(path):
    return json.loads((ROOT / path).read_text())


def check_tables(manifest, native):
    schemas.validate(manifest, read('schemas/tables-v1.schema.json'))
    assert manifest['upstreamCommit'] == oracle.UPSTREAM
    assert manifest['sourceSha256'] == hashlib.sha256((ROOT / 'original/DOOM/linuxdoom-1.10/tables.c').read_bytes()).hexdigest()
    expected = {'finesine': (10240, 'int32'), 'finecosine': (8192, 'int32'), 'finetangent': (4096, 'int32'), 'tantoangle': (2049, 'uint32')}
    assert len(manifest['tables']) == len(expected)
    assert {row['name'] for row in manifest['tables']} == set(expected)
    for row in manifest['tables']:
        assert (row['count'], row['wordType']) == expected[row['name']]
        assert {key: row[key] for key in ('count', 'sha256')} == native['tables'][row['name']]


def main():
    vector_schema = read('schemas/vectors-v1.schema.json')
    vectors = [read(f'test/fixtures/reference/{name}-v1.json') for name in ('numeric', 'geometry-synthetic', 'geometry-wad')]
    for document in vectors:
        schemas.validate(document, vector_schema)
        oracle.validate_vectors(document)
        assert document['build'] == vectors[0]['build']
    numeric, synthetic, geometry = vectors
    tables = read('tools/tables/manifest.json')
    native = read('test/fixtures/reference/native-table-hashes.json')
    check_tables(tables, native)
    pin = read('tools/wad/freedoom.lock.json')
    snapshot = read('test/fixtures/wad/snapshot.json')
    palette = read('test/fixtures/wad/palette.json')
    schemas.validate(palette, read('schemas/palette-v0.schema.json'))
    assert geometry['wadSha256'] == pin['wadSha256'] == snapshot['resourceIdentity']['wadSha256']
    assert snapshot['upstreamCommit'] == geometry['upstreamCommit']
    assert palette['resourceIdentity'] == snapshot['resourceIdentity']
    assert schemas.digest(bytes.fromhex(palette['rgbHex'])) == palette['resourceIdentity']['paletteSha256']
    camera = read('test/fixtures/reference/camera-e1m1.json')
    assert camera['wadSha256'] == geometry['wadSha256'] and camera['map'] == geometry['map']
    assert camera['upstreamCommit'] == geometry['upstreamCommit'] and camera['build'] == geometry['build']
    assert camera['rendererGoldenAvailable'] is False
    reference_schema = read('schemas/reference-v0.schema.json')
    for key in ('camera', 'width', 'height', 'detail', 'colormap', 'lighting', 'gametic'):
        schemas.validate(camera[key], reference_schema['properties'][key])
    nodes = next(lump for lump in snapshot['lumps'] if bytes.fromhex(lump['nameHex']).rstrip(b'\0') == b'NODES')
    assert nodes['sha256'] == camera['nodesSha256']
    assert camera['subsectorCount'] == snapshot['validation']['counts']['SSECTORS']
    origin = [camera['camera']['x'], camera['camera']['y']]
    assert any(row['function'] == 'R_PointInSubsector' and row['inputs'] == origin and row['outputs'] == [camera['spawnSubsector']] for row in geometry['vectors'])
    # Mutate shared contracts to prove checks are not merely parsing the happy path.
    failures = 0
    for field, value in [('schemaVersion', 2), ('wadSha256', '0'*64), ('upstreamCommit', '1'*40)]:
        bad = copy.deepcopy(geometry); bad[field] = value
        try:
            schemas.validate(bad, vector_schema); oracle.validate_vectors(bad)
        except (AssertionError, ValueError): failures += 1
        else: raise AssertionError('accepted mutated vector identity')
    for field, value in [('count', 1), ('sha256', '0'*64), ('wordType', 'uint32')]:
        bad = copy.deepcopy(tables)
        row = next(row for row in bad['tables'] if row['name'] == 'finesine'); row[field] = value
        try: check_tables(bad, native)
        except (AssertionError, ValueError): failures += 1
        else: raise AssertionError('accepted mutated table contract')
    print(f'PASS: {sum(len(v["vectors"]) for v in vectors)} schema/semantic vectors; 4 native/Solidity table identities; WAD/palette/camera binding; {failures} cross-contract mutations')


if __name__ == '__main__':
    main()
