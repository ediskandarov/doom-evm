#!/usr/bin/env python3
"""Complete static-world-view Phase 2 gate; Phase 1 (including Phase 0) stays unchanged.

No skip/resume mode: passed is written only after every command, fresh evidence,
and the final source/submodule guard succeed. --list and --self-test do not run
acceptance gates and never create a passed acceptance summary.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import re
import struct
import zlib
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from execution_budget import CONFIG, execution_env, load_gas_budget

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / 'artifacts/local/phase2-verification/summary.json'
UPSTREAM = 'a77dfb96cb91780ca334d0d4cfd86957558007e0'
FOLDERS = {'src', 'test', 'tools', 'scripts', 'docs', 'schemas', 'web'}
LOCAL_WEB = {'web/config.local.json', 'web/palette.local.json'}
DOCUMENTS = ['PORTING.md', 'docs/02-TECHNICAL-SPECIFICATION.md',
             'docs/03-IMPLEMENTATION-PLAN.md', 'docs/PHASE2-INTERFACES.md',
             *['docs/PHASE2-' + part + '.md' for part in
               ['GEOMETRY', 'DATA', 'DRAW', 'BSP', 'SEGS', 'PLANES', 'SPRITES',
                'SOURCE', 'TABLES', 'E2E', 'REPORT']]]
COVERAGE = {
    'plan 5 / 2A F geometry': ['geometry-native', 'foundry-tests'],
    'plan 5 / 2A G resource access': ['data-native', 'source-commitments', 'resource-measurements'],
    'plan 5 / 2A H indexed drawing': ['draw-native', 'draw-measurements', 'foundry-tests'],
    'plan 5 / 2B I BSP': ['bsp-native', 'bsp-instrumentation', 'foundry-tests'],
    'plan 5 / 2B J walls and wall-only Frame': ['segs-native', 'wall-measurements', 'full-renderer-e2e'],
    'plan 5 / 2C K planes': ['planes-native', 'foundry-tests', 'full-renderer-e2e'],
    'plan 5 / 2C L masked sprites': ['info-native', 'sprites-native', 'foundry-tests', 'full-renderer-e2e'],
    'plan 5 / 2C M orchestration and Frame': ['foundry-tests', 'full-renderer-e2e'],
    'plan 5 M1 / spec 9,11 ordinary deployment, native pixel diff, transaction/browser artifacts':
        ['full-native-renderer', 'source-measurements', 'full-renderer-e2e'],
    'all Phase 0/1 regressions': ['unchanged-phase1'],
    'spec 11 C mapping/deviations documentation': ['documentation-presence'],
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd).decode()


def source_hashes(root=ROOT):
    # Git inventory includes all tracked inputs and new nonignored sources. It
    # deliberately excludes ignored caches/chunks, output directories and pyc.
    names = git('ls-files', '-z', '--cached', '--others', '--exclude-standard', cwd=root).split('\0')
    result = {}
    for name in sorted(set(names) - {''}):
        parts = Path(name).parts
        if parts[0] in {'.toolchain', 'out', 'cache', 'artifacts', 'node_modules'}:
            continue
        if name in LOCAL_WEB or '__pycache__' in parts:
            continue
        if parts[0] not in FOLDERS and len(parts) != 1:
            continue
        path = root / name
        if path.is_symlink():
            require(path.is_file(), f'Unexpected source directory symlink: {name}')
            result[name] = {'sha256': sha(path), 'symlink': os.readlink(path)}
        else:
            require(path.is_file(), f'Missing source input: {name}')
            result[name] = sha(path)
    # Explicit policy input remains frozen even if a future ignore rule omits it.
    result['execution-budget.json'] = sha(root / 'execution-budget.json')
    return result


def original_submodules(root=ROOT):
    result = {}
    def visit(parent, prefix=''):
        for entry in git('ls-files', '--stage', '-z', cwd=parent).split('\0'):
            if not entry:
                continue
            record, name = entry.split('\t', 1)
            mode, pin, stage = record.split()
            if mode != '160000':
                continue
            require(stage == '0', f'Unmerged submodule {prefix + name}')
            path = parent / name
            actual = git('rev-parse', 'HEAD', cwd=path).strip()
            require(actual == pin, f'Submodule pin mismatch: {prefix + name}')
            status = git('status', '--porcelain', '--untracked-files=all', cwd=path)
            require(not status, f'Dirty original submodule {prefix + name}: {status}')
            result[prefix + name] = {'gitlink': pin, 'head': actual,
                                     'tree': git('rev-parse', 'HEAD^{tree}', cwd=path).strip()}
            visit(path, prefix + name + '/')
    visit(root)
    require(result.get('original/DOOM', {}).get('head') == UPSTREAM, 'Pinned original DOOM missing')
    return result


def snapshot():
    return {'git_head': git('rev-parse', 'HEAD').strip(),
            'source_sha256': source_hashes(), 'original_submodules': original_submodules()}


def unchanged(before, after):
    if before == after:
        return
    old, new = before.get('source_sha256', {}), after.get('source_sha256', {})
    changed = sorted(k for k in old.keys() | new.keys() if old.get(k) != new.get(k))
    raise RuntimeError('Sources/HEAD/original submodules changed during verification: ' +
                       (', '.join(changed[:30]) or 'HEAD or recursive submodule identity'))


def fresh(path, started_ns, allow_empty=False):
    path = Path(path)
    require(path.is_file() and (allow_empty or path.stat().st_size > 0), f'Missing/empty evidence: {path}')
    require(path.stat().st_mtime_ns >= started_ns, f'Stale evidence from a prior run: {path}')
    return path


def load_fresh(path, started_ns):
    return json.loads(fresh(path, started_ns).read_text())


def check_report_sources(report, baseline):
    hashes = report.get('sources', report.get('sourceHashes'))
    require(isinstance(hashes, dict) and hashes, 'Evidence has no source identities')
    for path, digest in hashes.items():
        known = baseline['source_sha256'].get(path)
        require(known is not None and known == digest, f'Evidence source mismatch: {path}')


def png_file(path, started_ns):
    path = fresh(path, started_ns)
    data = path.read_bytes()
    require(data.startswith(b'\x89PNG\r\n\x1a\n'), f'Invalid PNG evidence: {path}')
    offset, tags = 8, []
    while offset < len(data):
        require(offset + 12 <= len(data), f'Truncated PNG: {path}')
        size = struct.unpack_from('>I', data, offset)[0]
        require(offset + size + 12 <= len(data), f'Truncated PNG chunk: {path}')
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        crc = struct.unpack_from('>I', data, offset + 8 + size)[0]
        require(zlib.crc32(kind + payload) == crc, f'PNG CRC mismatch: {path}')
        if not tags:
            require(kind == b'IHDR' and size == 13, f'PNG header missing: {path}')
            width, height = struct.unpack_from('>II', payload)
            require(width >= 320 and height >= 200, f'Placeholder-sized PNG: {path}')
        tags.append(kind)
        offset += size + 12
    require(tags[-1:] == [b'IEND'] and b'IDAT' in tags, f'Incomplete PNG: {path}')


def phase1_evidence(started_ns, baseline, destination):
    report = load_fresh(ROOT / 'artifacts/local/phase1-verification/summary.json', started_ns)
    old = load_fresh(ROOT / 'artifacts/local/verification/summary.json', started_ns)
    archived = {}
    for value, count, label in [(report, 13, 'phase1'), (old, 12, 'phase0')]:
        require(value.get('passed') is True, 'Inherited Phase 0/1 gate did not pass')
        rows = value.get('results', [])
        require(len(rows) == count and all(r.get('exit_code') == 0 for r in rows), 'Incomplete inherited gate')
        require(value.get('git_head') == baseline['git_head'], 'Inherited gate used another commit')
        archive = destination / ('inherited-' + label)
        archive.mkdir(parents=True, exist_ok=True)
        summary = archive / 'summary.json'
        summary.write_text(json.dumps(value, indent=2) + '\n')
        archived[label] = {'summary': str(summary), 'sha256': sha(summary), 'logs': {}}
        for row in rows:
            # Successful quiet commands (notably forge fmt --check) emit no text.
            # Their exit status is checked above; the log must still be fresh.
            original = fresh(ROOT / row['log'], started_ns, allow_empty=True)
            copied = archive / (row['gate'] + '.log')
            shutil.copyfile(original, copied)
            archived[label]['logs'][str(copied)] = sha(copied)
    return {'phase1_commands': 13, 'phase0_commands': 12, 'archived': archived}


def benchmark_evidence(path, kind, count, started_ns, baseline):
    report = load_fresh(path, started_ns)
    require(report.get('kind') == kind, f'Wrong benchmark kind: {path}')
    check_report_sources(report, baseline)
    if kind == 'authenticated-wad-ordinary-deployment':
        require(report['deployment']['all1755RuntimeBytesVerified'] is True, 'Source runtimes not verified')
        require(len(report['deployment']['chunks']) == 1755 and len(report['reads']) == 4, 'Incomplete source evidence')
        require(len(report['rejections']) == 3 and all(x['status'] == '0x0' and x['logs'] == 0 for x in report['rejections']), 'Missing mined source rejection')
    elif kind == 'phase2-resource-ordinary-evm-access':
        require(report['deployment']['all1755RuntimeBytesVerified'] is True and len(report['deployment']['chunks']) == 1755, 'Resource runtimes not verified')
    elif kind == 'phase2-genuine-walls-ordinary-EVM':
        require(report['upload']['chunkCount'] == 1755, 'Wall resource deployment incomplete')
        native = json.loads((ROOT / 'test/fixtures/renderer/manifest.json').read_text())
        require({r['name'] for r in report['results']} == {f'walls-angle{i}' for i in range(8)}, 'Missing wall viewpoints')
        for row in report['results']:
            case = next(c for c in native['cases'] if c['name'] == row['name'])
            require(row['mode'] == case['mode'] == 'walls' and row['angle'] == case['angle']
                    and row['pixelsSha256'] == case['frameSha256'], 'Wall native comparison mismatch')
    calibration = report['calibration']
    require(calibration['actualMsize'] == calibration.get('derivedHighWater', calibration.get('decodedHighWater')) == 320,
            'Literal memory calibration failed')
    rows = report.get('results', report.get('reads', []))
    require(len(rows) == count, f'Incomplete benchmark: {path}')
    for row in rows:
        require(row.get('transactionGas', 0) > 0, 'Missing measured transaction gas')
        transaction = row.get('normalTransactionHash', row.get('transactionHash'))
        require(isinstance(transaction, str) and re.fullmatch(r'0x[0-9a-fA-F]{64}', transaction)
                and int(transaction, 16) != 0, 'Missing mined transaction identity')
        memory = row.get('actualMemoryBytes', [])
        require(memory and max(memory) > 0 and all(x >= 0 and x % 32 == 0 for x in memory), 'Missing literal memory measurements')
    return {'report': str(path), 'sha256': sha(path), 'cases': count}


def draw_evidence(path, started_ns, baseline):
    report = load_fresh(path, started_ns)
    check_report_sources(report, baseline)
    require(report.get('kind') == 'phase2-draw-evm-measurements', 'Wrong draw measurement kind')
    require(report['calibration']['actualMsize'] == report['calibration']['derivedHighWater'] == 416, 'Draw memory calibration failed')
    require(len(report.get('measurements', [])) == 6, 'Incomplete draw measurement')
    for row in report['measurements']:
        require(row.get('drawGas', 0) > 0 and row.get('wholeCallHighWaterBytes', 0) > 0, 'Missing draw gas/memory')
    return {'report': str(path), 'sha256': sha(path), 'cases': 6}


def positive(value, label, allow_zero=False):
    require(isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
            and (value >= 0 if allow_zero else value > 0), 'Missing measured ' + label)


def transaction_hash(value):
    require(isinstance(value, str) and re.fullmatch(r'0x[0-9a-fA-F]{64}', value)
            and int(value, 16) != 0, 'Missing transaction hash')


def renderer_evidence(prefix, started_ns, baseline):
    # Final report schema is intentionally strict. The e2e verifier supplies the
    # transaction/browser proofs; this runner also verifies its on-disk pixels.
    report = load_fresh(str(prefix) + '.json', started_ns)
    require(report.get('kind') == 'doom-world-view-ordinary-e2e' and report.get('pass') is True,
            'Full renderer verifier has not passed')
    check_report_sources(report, baseline)
    native = json.loads((ROOT / 'test/fixtures/renderer/manifest.json').read_text())
    require(report['rendererCommit'] == baseline['git_head'], 'Renderer evidence is from another commit')
    require(report['resourceIdentity'] == native['resourceIdentity'], 'Renderer resource identity differs')
    expected_acceptance = dict(fullCaseCount=8, pixelDiffCount=0, ordinaryResourceDeployment=True,
                               ordinaryDoomDeployment=True, oneFramePerTransaction=True,
                               websocketReceiptPixelsEqual=True, canvasPixelsEqual=True,
                               wallFramePixelDiffCount=0, measuredGasPositive=True, measuredMemoryPositive=True)
    require(report['acceptance'] == expected_acceptance, 'Incomplete full-frame acceptance')
    deployment = report['deployment']
    require(deployment['all1755RuntimeBytesVerified'] is True and len(deployment['chunks']) == 1755,
            'Missing ordinary resource deployment')
    for label in ['doom', 'normalProbe', 'instrumentedProbe']:
        positive(deployment[label]['gas'], label + ' deployment gas')
        transaction_hash(deployment[label]['transactionHash'])
    positive(deployment['doom']['runtimeBytes'], 'production runtime size')
    require(re.fullmatch(r'[0-9a-f]{64}', deployment['doom']['runtimeSha256']), 'Missing production runtime identity')
    blob = (ROOT / 'artifacts/local/wad/resources.bin').read_bytes()
    require(hashlib.sha256(blob).hexdigest() == report['blobSha256'], 'Renderer resource blob mismatch')
    runtime_digests = []
    for i, chunk in enumerate(deployment['chunks']):
        runtime = b'\0' + blob[i*16384:(i+1)*16384]
        digest = hashlib.sha256(runtime).hexdigest()
        require(chunk['index'] == i and chunk['runtimeBytes'] == len(runtime)
                and chunk['runtimeSha256'] == digest, 'Wrong deployed runtime chunk')
        transaction_hash(chunk['transactionHash'])
        positive(chunk['gas'], 'chunk deployment gas')
        runtime_digests.append(bytes.fromhex(digest))
    require(hashlib.sha256(b''.join(runtime_digests)).hexdigest() == report['chunkCommitment'], 'Ordered runtime commitment mismatch')
    require(sha(ROOT / 'test/fixtures/phase2_data/directory.bin') == report['directorySha256'], 'Renderer directory mismatch')
    require(report['calibration']['actualMsize'] == report['calibration']['derivedHighWater'] == 320, 'Full-frame memory calibration failed')
    require(len(report['scenes']) == 8 and {s['name'] for s in report['scenes']} == {f'full-angle{i}' for i in range(8)}, 'Missing full viewpoints')
    frames = []
    for angle in range(8):
        name = f'full-angle{angle}'
        case = next(c for c in native['cases'] if c['name'] == name)
        require(case['mode'] == 'full' and case['angle'] == angle * 0x20000000, 'Wrong native pass')
        scene = next(s for s in report['scenes'] if s['name'] == name)
        require(scene['mode'] == 'full' and scene['frameSha256'] == case['frameSha256']
                and scene['pixelDiffCount'] == 0 and scene['resourceIdentity'] == native['resourceIdentity'], 'Full scene evidence mismatch')
        require(scene['camera'] == {k: case['scene'][k] for k in ['x', 'y', 'z', 'angle']}, 'Actual EVM camera differs')
        require(scene['counts'] == [case['scene'][k] for k in ['spawnedThings', 'drawsegs', 'visplanes', 'vissprites', 'subsectors']], 'Actual EVM renderer counts differ')
        require(scene['gametic'] == 0 and scene['paletteVariant'] == 0 and scene['resolution'] == [320, 200], 'Full scene settings differ')
        for key in ['gasUsed', 'ethCallMs', 'instrumentedEthCallMs', 'sendToReceiptMs']:
            positive(scene[key], name + ' ' + key)
        require(len(scene['operationGas']) == 3 and len(scene['actualMemoryBytes']) == 4, 'Missing renderer region metrics')
        for value in scene['operationGas']:
            positive(value, 'operation gas')
        for value in scene['actualMemoryBytes']:
            positive(value, 'literal MSIZE')
            require(value % 32 == 0, 'MSIZE is not EVM word rounded')
        transaction_hash(scene['transactionHash'])
        transaction_hash(scene['instrumentedTransactionHash'])
        folder = Path(str(prefix) + '.frames') / name
        pixels = fresh(folder / 'pixels.bin', started_ns)
        require(pixels.stat().st_size == 64000 and sha(pixels) == case['frameSha256'], f'Full pixel mismatch: {name}')
        require(pixels.read_bytes() == (ROOT / 'test/fixtures/renderer' / name / 'pixels.bin').read_bytes(), f'Native pixel bytes differ: {name}')
        reference = load_fresh(folder / 'reference.json', started_ns)
        diff = load_fresh(folder / 'diff.json', started_ns)
        require(reference['frameSha256'] == case['frameSha256'], f'Frame reference mismatch: {name}')
        require(reference['resourceIdentity'] == native['resourceIdentity'], f'Resource identity mismatch: {name}')
        expected_reference = json.loads((ROOT / 'test/fixtures/renderer' / name / 'reference.json').read_text())
        require({k: v for k, v in reference.items() if k != 'provenance'} ==
                {k: v for k, v in expected_reference.items() if k != 'provenance'}, f'Render settings mismatch: {name}')
        require({k: v for k, v in reference['provenance'].items() if k != 'build'} ==
                {k: v for k, v in expected_reference['provenance'].items() if k != 'build'}, f'Native provenance mismatch: {name}')
        require(diff['mismatchCount'] == 0 and diff['mismatches'] == []
                and diff['expectedSha256'] == diff['actualSha256'] == case['frameSha256'], f'Nonzero or unbound pixel diff: {name}')
        png_file(folder / 'frame.png', started_ns)
        png_file(folder / 'diff.png', started_ns)
        frames.append({'name': name, 'sha256': sha(pixels), 'artifacts':
                       {leaf: sha(folder / leaf) for leaf in ['pixels.bin', 'reference.json', 'frame.png', 'diff.json', 'diff.png']}})
    browser = load_fresh(str(prefix) + '.browser.json', started_ns)
    png_file(str(prefix) + '.browser.png', started_ns)
    require(browser.get('kind') == 'doom-world-view-browser', 'Synthetic browser evidence cannot satisfy M1')
    case = next(c for c in native['cases'] if c['name'] == browser['referenceCase'])
    require(case['mode'] == 'full' and browser['receiptPixelsSha256'] == case['frameSha256'], 'Browser receipt is not a full native frame')
    require(browser.get('allCanvasPixelsMatchReceipt') is True, 'Canvas/receipt mismatch')
    proof = browser['proof']
    require(proof['done'] is True and proof['ready'] is True and proof['errors'] == []
            and proof['rendererKind'] == 'doom-world-view' and proof['fallbackVerified'] is True
            and proof['duplicates'] >= 2, 'Browser lifecycle/renderer evidence incomplete')
    require(proof['paletteSha256'] == native['resourceIdentity']['paletteSha256'], 'Browser palette mismatch')
    require(proof['frames'] and all(f['pixelBytes'] == 64000 for f in proof['frames']), 'Incomplete browser pixel array')
    require('receipt' in {f['source'] for f in proof['frames']}, 'Missing receipt fallback frame')
    palette = bytes.fromhex(json.loads((ROOT / 'test/fixtures/wad/palette.json').read_text())['rgbHex'])
    native_pixels = (ROOT / 'test/fixtures/renderer' / case['name'] / 'pixels.bin').read_bytes()
    rgba = b''.join(palette[v*3:v*3+3] + b'\xff' for v in native_pixels)
    require(proof['rgbaSha256'] == hashlib.sha256(rgba).hexdigest(), 'Actual Canvas RGBA hash mismatch')
    require(browser['config']['address'] == deployment['doom']['address']
            and browser['config']['resourceIdentity'] == native['resourceIdentity'], 'Browser used another deployment')
    config = load_fresh(str(prefix) + '.config.json', started_ns)
    require(config == browser['config'], 'Browser config artifact mismatch')
    require(len(report['productionFrames']) == 2, 'Missing actual production Frame transactions')
    for i, frame in enumerate(report['productionFrames']):
        require(frame['sequence'] == i + 1 and frame['method'] == ['stepAndRender', 'renderFrame'][i]
                and frame['oneFrame'] is True and frame['websocketReceiptPixelsEqual'] is True
                and frame['pixelBytes'] == 64000 and frame['abiDataBytes'] == 64128
                and frame['frameSha256'] == report['scenes'][0]['frameSha256'], 'Production event proof mismatch')
        transaction_hash(frame['transactionHash'])
        for key in ['gasUsed', 'ethCallMs', 'sendToReceiptMs', 'eventDeliveryMs']:
            positive(frame[key], 'production ' + key)
    require({r['name'] for r in report['rejections']} == {'wrong-driver', 'buttons', 'sequence-replay', 'sequence-skip'}
            and len(report['rejections']) == 4, 'Missing mined rollback cases')
    for rejection in report['rejections']:
        require(rejection['status'] == '0x0' and rejection['logs'] == 0
                and rejection['countersUnchanged'] is True, 'Missing mined failure or changed frame state')
        transaction_hash(rejection['transactionHash'])
        positive(rejection['gasUsed'], 'mined rejection gas')
    wall = report['wallFrame']
    expected_wall = next(c for c in native['cases'] if c['name'] == 'walls-angle0')
    require(wall['name'] == 'walls-angle0' and wall['mode'] == 'walls' and wall['oneFrame'] is True
            and wall['pixelDiffCount'] == 0 and wall['frameSha256'] == expected_wall['frameSha256'], 'Wall-only Frame proof mismatch')
    positive(wall['gasUsed'], 'wall Frame transaction gas')
    transaction_hash(wall['transactionHash'])
    wall_folder = Path(str(prefix) + '.frames/walls-angle0')
    require(sha(fresh(wall_folder / 'pixels.bin', started_ns)) == expected_wall['frameSha256'], 'Wall Frame bytes differ')
    wall_diff = load_fresh(wall_folder / 'diff.json', started_ns)
    require(wall_diff['mismatchCount'] == 0 and wall_diff['actualSha256'] == expected_wall['frameSha256'], 'Wall diff mismatch')
    png_file(wall_folder / 'frame.png', started_ns)
    png_file(wall_folder / 'diff.png', started_ns)
    timings = report['browser']['timings']
    require(len(timings) == 2, 'Missing browser latency measurements')
    for measured in timings:
        transaction_hash(measured['transactionHash'])
        require(any(f['transactionHash'] == measured['transactionHash'] for f in proof['frames']), 'Browser timing refers to no displayed frame')
        for key in ['sendToReceiptMs', 'eventDeliveryMs', 'inputToCanvasMs']:
            positive(measured[key], 'browser ' + key)
        positive(measured['canvasPutImageDataMs'], 'Canvas write duration', allow_zero=True)
    positive(report['browser']['totalCheckMs'], 'browser total duration')
    return {'report': str(prefix) + '.json', 'sha256': sha(str(prefix) + '.json'), 'frames': frames,
            'browser_sha256': sha(str(prefix) + '.browser.json'),
            'browser_screenshot_sha256': sha(str(prefix) + '.browser.png')}


def gates(output, port):
    folder = output.parent
    def command(name, args, timeout=600, evidence=None, env=None):
        return dict(name=name, args=args, timeout=timeout, evidence=evidence, env=env or {})
    wad = 'artifacts/local/freedoom/freedoom1.wad'
    result = [
        command('wad-bootstrap-download', ['node', 'tools/wad/download.ts', 'artifacts/local/freedoom'], 180),
        command('wad-bootstrap-pack', ['node', 'tools/wad/pack.ts', wad, 'artifacts/local/wad'], 120),
        command('pinned-test-chunks', ['python3', 'tools/reference/phase2_data/prepare_chunks.py'], 120),
        command('unchanged-phase1', ['python3', 'scripts/verify-phase1.py'], 1800, lambda start, base: phase1_evidence(start, base, folder)),
        command('all-index-tables', ['python3', 'tools/tables/generate.py']),
    ]
    for name, path in [('geometry-native', 'phase2_geometry/reference.py'), ('data-native', 'phase2_data/reference.py'),
                       ('draw-native', 'phase2_draw/reference.py'), ('info-native', 'info/generate.py'),
                       ('full-native-renderer', 'renderer/verify.py'), ('bsp-native', 'phase2_bsp/reference.py'),
                       ('bsp-instrumentation', 'phase2_bsp/instrument.py'), ('segs-native', 'phase2_segs/reference.py'),
                       ('planes-native', 'phase2_planes/reference.py'), ('sprites-native', 'phase2_sprites/verify.py')]:
        result.append(command(name, ['python3', 'tools/reference/' + path, '--check']))
    result += [
        command('source-commitments', ['node', 'tools/wad/check-source-identity.mjs']),
        command('telemetry-patcher-tests', ['node', '--test', 'tools/reference/phase2_data/instrument.test.mjs']),
        command('format', ['.toolchain/bin/forge', 'fmt', '--check']),
        command('foundry-tests', ['.toolchain/bin/forge', 'test', '--fuzz-seed', '0x44', '-vv'], 1200),
    ]
    draw = folder / 'draw-measurements.json'
    result.append(command('draw-measurements', ['node', 'tools/reference/phase2_draw/measure.mjs', str(draw)],
                          evidence=lambda start, base: draw_evidence(draw, start, base), env={'DRAW_ANVIL_PORT': str(port)}))
    for name, path, kind, count in [
        ('resource-measurements', 'phase2_data/benchmark.mjs', 'phase2-resource-ordinary-evm-access', 6),
        ('source-measurements', 'phase2_source/verify.mjs', 'authenticated-wad-ordinary-deployment', 4),
        ('wall-measurements', 'phase2_segs/benchmark.mjs', 'phase2-genuine-walls-ordinary-EVM', 8),
    ]:
        target = folder / (name + '.json')
        result.append(command(name, ['node', 'tools/reference/' + path, '--output', str(target), '--port', str(port)],
                              1200, lambda start, base, target=target, kind=kind, count=count:
                              benchmark_evidence(target, kind, count, start, base)))
    prefix = folder / 'renderer'
    result.append(command('full-renderer-e2e', ['node', 'tools/renderer/verify.mjs', '--output-prefix', str(prefix),
                                               '--port', str(port)], 1800,
                          lambda start, base: renderer_evidence(prefix, start, base)))
    return result


def stop(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()


def run_command(gate, log_path, cwd=ROOT):
    started = time.monotonic()
    requested_env = dict(os.environ, **gate.get('env', {}))
    child_env = execution_env(requested_env)
    result = {'gate': gate['name'], 'command': gate['args'], 'timeout_seconds': gate['timeout'],
              'environment_overrides': gate.get('env', {}), 'log': str(log_path), 'exit_code': None,
              'execution_budget': dict(load_gas_budget(requested_env), config_path='execution-budget.json',
                                       config_sha256=sha(CONFIG),
                                       python_helper_sha256=sha(ROOT/'scripts/execution_budget.py'),
                                       node_helper_sha256=sha(ROOT/'tools/execution-budget.mjs'))}
    with log_path.open('w') as log:
        try:
            process = subprocess.Popen(gate['args'], cwd=cwd,
                                       env=child_env,
                                       stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as error:
            log.write(str(error) + '\n')
            result.update(exit_code=127, error=str(error))
        else:
            try:
                result['exit_code'] = process.wait(timeout=gate['timeout'])
            except subprocess.TimeoutExpired:
                stop(process)
                result.update(exit_code=124, error='Command timeout; process group terminated')
            except KeyboardInterrupt:
                stop(process)
                result.update(exit_code=130, error='Interrupted; process group terminated')
    result['elapsed_seconds'] = round(time.monotonic() - started, 3)
    result['log_sha256'] = sha(log_path)
    return result


def write_report(output, report, started):
    report['elapsed_seconds'] = round(time.monotonic() - started, 3)
    temporary = output.with_name(output.name + '.tmp')
    temporary.write_text(json.dumps(report, indent=2) + '\n')
    temporary.replace(output)


def self_test():
    with tempfile.TemporaryDirectory(prefix='doom-phase2-gate-selftest-') as tmp:
        folder = Path(tmp)
        empty = folder / 'quiet-success.log'
        empty.write_text('')
        fresh(empty, 0, allow_empty=True)
        for name, args, timeout, expected in [
            ('success', [sys.executable, '-c', 'print("ok")'], 5, 0),
            ('failure', [sys.executable, '-c', 'raise SystemExit(17)'], 5, 17),
            ('missing', [str(folder / 'missing-command')], 5, 127),
            ('timeout', [sys.executable, '-c', 'import time; time.sleep(10)'], 0.1, 124),
        ]:
            result = run_command(dict(name=name, args=args, timeout=timeout), folder / (name + '.log'))
            require(result['exit_code'] == expected and result['log_sha256'], 'Command failure handling regressed')
        (folder / 'renderer.json').write_text(json.dumps({'kind': 'doom-world-view-ordinary-e2e', 'pass': False}))
        for operation in [lambda: fresh(empty, 0),
                          lambda: fresh(empty, time.time_ns() + 1000000, allow_empty=True),
                          lambda: renderer_evidence(folder / 'renderer', 0, {}),
                          lambda: unchanged({'source_sha256': {'a': '1'}}, {'source_sha256': {'a': '2'}}),
                          lambda: fresh(folder / 'missing.json', 0),
                          lambda: fresh(folder / 'success.log', time.time_ns() + 1000000),
                          lambda: check_report_sources({'sources': {'bad': '0'}}, {'source_sha256': {}})]:
            try:
                operation()
            except RuntimeError:
                pass
            else:
                raise RuntimeError('Fail-closed self-test unexpectedly accepted invalid evidence')
    print('PASS runner self-test: subprocess errors/timeouts, source drift, stale/missing evidence; no acceptance gates run')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT, help='summary JSON; logs and generated evidence use its parent directory')
    parser.add_argument('--port', type=int, default=18567, help='sequential Phase2 benchmark/E2E Anvil port; Phase0/1 retain their defaults')
    parser.add_argument('--list', action='store_true', help='print commands without running or producing acceptance evidence')
    parser.add_argument('--self-test', action='store_true', help='test runner failures in a temporary directory; no acceptance gates')
    args = parser.parse_args()
    require(1024 < args.port < 65536, 'Invalid Anvil port')
    output = args.output.resolve()
    try:
        relative = output.relative_to(ROOT)
        require(relative.parts[:2] == ('artifacts', 'local'), 'In-repository output must be under artifacts/local')
    except ValueError:
        pass
    commands = gates(output, args.port)
    if args.list:
        print(json.dumps([{k: v for k, v in gate.items() if k != 'evidence'} for gate in commands], indent=2))
        return
    if args.self_test:
        self_test()
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'Signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    started = time.monotonic()
    report = {'scope': 'Complete static E1M1 world views; Phase2 and all inherited Phase0/1 gates; no gameplay ticks/HUD',
              'run_id': str(uuid.uuid4()), 'utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'coverage': COVERAGE, 'planned_gates': [x['name'] for x in commands], 'results': [], 'passed': False,
              'execution_budget': dict(load_gas_budget(), config_path='execution-budget.json',
                                       config_sha256=sha(CONFIG),
                                       python_helper_sha256=sha(ROOT/'scripts/execution_budget.py'),
                                       node_helper_sha256=sha(ROOT/'tools/execution-budget.mjs'))}
    # Invalidate a prior success before scanning inputs or starting any child.
    write_report(output, report, started)
    try:
        baseline = snapshot()
        report.update(baseline)
        report['documentation'] = {name: sha(ROOT / name) for name in DOCUMENTS}
        require(all((ROOT / name).stat().st_size > 0 for name in DOCUMENTS), 'Empty required documentation')
        report['results'].append({'gate': 'documentation-presence', 'exit_code': 0,
                                  'note': 'Presence and hashes only; function-by-function fidelity audit remains the documented integrator review.'})
        write_report(output, report, started)
        for gate in commands:
            unchanged(baseline, snapshot())
            print(f'Running {gate["name"]}...', flush=True)
            gate_started_ns = time.time_ns()
            row = run_command(gate, output.parent / (gate['name'] + '.log'))
            report['results'].append(row)
            write_report(output, report, started)
            require(row['exit_code'] == 0, f'FAILED {gate["name"]}: exit {row["exit_code"]}; {row["log"]}')
            unchanged(baseline, snapshot())
            if gate['evidence']:
                row['evidence'] = gate['evidence'](gate_started_ns, baseline)
            write_report(output, report, started)
            print(f'PASS {gate["name"]} ({row["elapsed_seconds"]}s)', flush=True)
        unchanged(baseline, snapshot())
        require(len(report['results']) == len(commands) + 1, 'Incomplete gate sequence')
        report['passed'] = True
        report['source_guard_passed'] = True
        write_report(output, report, started)
    except BaseException as error:
        report['passed'] = False
        report['error'] = f'{type(error).__name__}: {error}'
        write_report(output, report, started)
        print(f'FAILED: {error}; summary {output}', file=sys.stderr)
        return 1
    print(f'PASS: all {len(commands)} Phase2 commands plus required documentation; {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
