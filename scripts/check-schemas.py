#!/usr/bin/env python3
"""Validate Phase 0 JSON contracts and cross-file invariants without dependencies.

This implements only the explicit JSON Schema keywords used by these four
schemas, rejects unknown validation keywords, and is not a general JSON Schema
implementation. Install jsonschema optionally for a second independent check.
"""
import copy
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'test/fixtures/phase0'
SCHEMAS = {'bundle': 'resource-bundle', 'palette': 'palette', 'frame': 'frame', 'reference': 'reference'}
KEYWORDS = {'$schema', '$id', 'title', 'type', 'properties', 'required', 'additionalProperties',
            'minimum', 'maximum', 'minLength', 'pattern', 'const', 'enum', 'items', 'anyOf'}
ZERO_HASH = '0' * 64


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(value, schema, location='$'):
    require(not set(schema) - KEYWORDS, f'{location}: unsupported schema keywords')
    if 'anyOf' in schema:
        for variant in schema['anyOf']:
            try:
                validate(value, variant, location)
                break
            except ValueError:
                pass
        else:
            raise ValueError(f'{location}: no allowed schema variant')
    if 'const' in schema:
        expected = schema['const']
        require(type(value) is type(expected) and value == expected, f'{location}: wrong constant')
    if 'enum' in schema:
        require(value in schema['enum'], f'{location}: invalid enum')
    kind = schema.get('type')
    checks = {'object': dict, 'array': list, 'string': str, 'integer': int}
    if kind:
        require(kind in checks and type(value) is checks[kind], f'{location}: expected {kind}')
    if kind == 'object':
        require(set(schema['required']) <= set(value), f'{location}: missing fields')
        require(not set(value) - set(schema['properties']), f'{location}: unknown fields')
        for key, item in value.items():
            validate(item, schema['properties'][key], f'{location}.{key}')
    elif kind == 'array':
        for index, item in enumerate(value):
            validate(item, schema['items'], f'{location}[{index}]')
    elif kind == 'integer':
        require(schema['minimum'] <= value <= schema['maximum'], f'{location}: out of range')
    elif kind == 'string':
        require(len(value) >= schema.get('minLength', 0), f'{location}: empty string')
        if 'pattern' in schema:
            require(re.fullmatch(schema['pattern'], value) is not None, f'{location}: bad format')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def manifest_digest(bundle):
    manifest = {key: value for key, value in bundle.items() if key not in ('resourceIdentity', 'blobFile')}
    canonical = json.dumps(manifest, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii')
    return digest(canonical)


def seal_manifest(documents):
    bundle_hash = manifest_digest(documents['bundle'])
    for document in documents.values():
        document['resourceIdentity']['bundleSha256'] = bundle_hash


def check(documents, payloads, schemas):
    for name, value in documents.items():
        validate(value, schemas[name], name)
    bundle, palette, frame, reference = (documents[n] for n in SCHEMAS)
    identity = bundle['resourceIdentity']
    for name, value in documents.items():
        require(value['resourceIdentity'] == identity, f'{name}: resource identity mismatch')
    kind = bundle['provenance']['kind']
    require(palette['kind'] == frame['kind'] == reference['provenance']['kind'] == kind,
            'mixed synthetic and WAD evidence')
    if kind == 'synthetic':
        require(identity['wadSha256'] == ZERO_HASH, 'synthetic bundle claims a WAD hash')
        require(reference['scope'] == 'synthetic-transport', 'synthetic fixture claims engine coverage')
    else:
        require(identity['wadSha256'] != ZERO_HASH, 'WAD identity cannot be zero')
        for source in (bundle['provenance'], reference['provenance']):
            require(source['wadSha256'] == identity['wadSha256'], 'WAD provenance mismatch')
        require(bundle['provenance']['upstreamCommit'] == reference['provenance']['upstreamCommit'],
                'reference upstream mismatch')
        require(reference['scope'] != 'synthetic-transport', 'WAD reference claims synthetic scope')
    blob = payloads[bundle['blobFile']]
    require(len(blob) == bundle['blobByteLength'], 'blob byte length mismatch')
    require(digest(blob) == bundle['blobSha256'], 'bundle payload hash mismatch')
    require(manifest_digest(bundle) == identity['bundleSha256'], 'bundle manifest identity mismatch')
    # A normalized bundle packs lumps in ID order without gaps or overlaps.
    cursor = 0
    for index, lump in enumerate(bundle['lumps']):
        require(lump['id'] == index and index < 2**32 - 1, 'lump IDs must be contiguous; null reserved')
        require(lump['offset'] == cursor, 'lump bounds have overlap or gap')
        cursor += lump['length']
        require(cursor <= len(blob) and cursor <= 2**32 - 1, 'lump bounds exceed blob')
    require(cursor == len(blob), 'lump descriptors do not cover blob')
    rgb = bytes.fromhex(palette['rgbHex'])
    require(len(rgb) == 768 and digest(rgb) == identity['paletteSha256'], 'palette length/hash mismatch')
    pixels = payloads[frame['pixelsFile']]
    require(len(pixels) == frame['pixelsByteLength'] == frame['width'] * frame['height'],
            'frame pixel length/resolution mismatch')
    require(digest(pixels) == frame['pixelsSha256'], 'frame payload hash mismatch')
    require(reference['frameSha256'] == frame['pixelsSha256'], 'golden frame hash mismatch')
    require((reference['width'], reference['height']) == (frame['width'], frame['height']),
            'golden resolution mismatch')


def set_field(documents, path, value):
    target = documents
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value


def main():
    documents = {name: json.loads((FIXTURES / f'{name}.json').read_text()) for name in SCHEMAS}
    schemas = {name: json.loads((ROOT / 'schemas' / f'{schema}-v0.schema.json').read_text())
               for name, schema in SCHEMAS.items()}
    # Validate paths structurally before reading them; no traversal or arbitrary absolute paths.
    for name, document in documents.items():
        validate(document, schemas[name], name)
    payloads = {documents['bundle']['blobFile']: (FIXTURES / documents['bundle']['blobFile']).read_bytes(),
                documents['frame']['pixelsFile']: (FIXTURES / documents['frame']['pixelsFile']).read_bytes()}
    check(documents, payloads, schemas)
    try:
        import jsonschema
    except ImportError:
        print('jsonschema unavailable; strict supported-keyword validator used (Python stdlib)')
    else:
        for name, document in documents.items():
            jsonschema.Draft202012Validator.check_schema(schemas[name])
            jsonschema.Draft202012Validator(schemas[name]).validate(document)
        print('Independent jsonschema Draft 2020-12 check passed')
    # The fixture tests numeric byte serialization only, not original DOOM arithmetic.
    require(struct.unpack('<4i', payloads['bundle.bin']) == (1, -2, 65536, -65536),
            'little-endian signed int32 serialization changed')
    mutations = [
        ('unknown schema', ['bundle', 'schemaVersion'], 1),
        ('negative offset', ['bundle', 'lumps', 0, 'offset'], -1),
        ('oversized offset', ['bundle', 'lumps', 0, 'offset'], 2**32),
        ('overflow bounds', ['bundle', 'lumps', 0, 'length'], 2**32 - 1),
        ('overlap', ['bundle', 'lumps', 1, 'offset'], 7),
        ('gap', ['bundle', 'lumps', 1, 'offset'], 9),
        ('missing coverage', ['bundle', 'lumps', 1, 'length'], 7),
        ('duplicate ID', ['bundle', 'lumps', 1, 'id'], 0),
        ('null sentinel ID', ['bundle', 'lumps', 1, 'id'], 2**32-1),
        ('invalid name size', ['bundle', 'lumps', 0, 'nameHex'], '00'),
        ('wrong byte order', ['bundle', 'byteOrder'], 'big-endian'),
        ('path traversal', ['bundle', 'blobFile'], '../bundle.bin'),
        ('boolean integer', ['frame', 'width'], True),
        ('zero width', ['frame', 'width'], 0),
        ('width mismatch', ['frame', 'width'], 319),
        ('zero frame ID', ['frame', 'frameId'], 0),
        ('input overflow', ['frame', 'inputSeq'], 2**32),
        ('wrong frame hash', ['frame', 'pixelsSha256'], ZERO_HASH),
        ('wrong golden hash', ['reference', 'frameSha256'], ZERO_HASH),
        ('wrong resolution', ['reference', 'height'], 201),
        ('out-of-range coordinate', ['reference', 'camera', 'x'], 2**31),
        ('out-of-range angle', ['reference', 'camera', 'angle'], -1),
        ('missing palette bytes', ['palette', 'rgbHex'], '00'),
        ('wrong palette bytes', ['palette', 'rgbHex'], '00'*768),
        ('identity mismatch', ['palette', 'resourceIdentity', 'paletteVariant'], 1),
        ('fake WAD reference', ['reference', 'provenance', 'kind'], 'wad'),
        ('fake engine reference', ['reference', 'scope'], 'world-view'),
    ]
    for label, path, value in mutations:
        malformed = copy.deepcopy(documents)
        set_field(malformed, path, value)
        if path[0] == 'bundle':
            # Authenticate the malformed descriptor, so bounds tests exercise bounds, not just hashes.
            seal_manifest(malformed)
        try:
            check(malformed, payloads, schemas)
        except ValueError:
            continue
        raise ValueError(f'mutation accepted: {label}')
    for field in ('wadSha256', 'bundleSha256', 'paletteSha256'):
        malformed = copy.deepcopy(documents)
        for document in malformed.values():
            document['resourceIdentity'][field] = 'f' * 64
        try:
            check(malformed, payloads, schemas)
        except ValueError:
            continue
        raise ValueError(f'forged shared identity accepted: {field}')
    for filename in payloads:
        malformed_payloads = dict(payloads)
        malformed_payloads[filename] = b'\xff' + payloads[filename][1:]
        try:
            check(documents, malformed_payloads, schemas)
        except ValueError:
            continue
        raise ValueError(f'corrupt payload accepted: {filename}')
    # A fabricated in-memory WAD record exercises the schema's real-reference branch.
    # It is never persisted or reported as a real WAD/C oracle.
    wad_documents = copy.deepcopy(documents)
    source = {'kind': 'wad', 'wadName': 'schema-test-only.wad', 'wadSha256': '1'*64,
              'upstreamCommit': 'a'*40, 'license': 'schema-only fabricated provenance'}
    wad_documents['bundle']['provenance'] = source
    wad_documents['reference']['provenance'] = {**source, 'map': 'E1M1', 'build': {
        'compiler': 'schema-test', 'version': '0', 'target': 'schema-test', 'flags': [],
        'patchSha256': digest(b''), 'harnessSha256': '2'*64,
        'integerSemantics': 'must record actual reference build behavior',
        'doubleSemantics': 'must record actual FixedDiv2 floating conversion behavior'}}
    wad_documents['reference']['scope'] = 'world-view'
    wad_documents['palette']['kind'] = wad_documents['frame']['kind'] = 'wad'
    for document in wad_documents.values():
        document['resourceIdentity']['wadSha256'] = source['wadSha256']
    seal_manifest(wad_documents)
    check(wad_documents, payloads, schemas)
    required_oracle = ['build', 'map', 'upstreamCommit', 'wadSha256']
    for field in required_oracle:
        malformed = copy.deepcopy(wad_documents)
        del malformed['reference']['provenance'][field]
        try:
            check(malformed, payloads, schemas)
        except ValueError:
            continue
        raise ValueError(f'incomplete WAD reference accepted: {field}')
    malformed = copy.deepcopy(documents)
    malformed['bundle']['lumps'][0]['nameHex'] = b'RENAMED!'.hex()
    try:
        check(malformed, payloads, schemas)
    except ValueError:
        pass
    else:
        raise ValueError('altered descriptor with stale bundle hash accepted')
    print(f'PASS: 4 fixture contracts, little-endian vector, {len(mutations)+10} malformed cases')
    print('Synthetic serialization fixtures only; no WAD parse or C equivalence claim.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
