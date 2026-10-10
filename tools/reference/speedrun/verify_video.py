#!/usr/bin/env python3
"""Verify actual Frame receipts, native-equivalent gameplay and palette/MP4 output."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import struct
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
FRAME_TOPIC = '0x8c71e36358c1759fef7ef5d3abaf6c85f385b13e3579e3d62b00529c4babe922'
sha = lambda b: hashlib.sha256(b).hexdigest()


def states(data, delta=False):
    rows = []
    previous = b''
    pos = 0
    while pos < len(data):
        size = struct.unpack_from('>I', data, pos)[0]
        pos += 4
        row = data[pos:pos + size]
        assert len(row) == size
        if delta:
            row = bytes(b ^ (previous[i] if i < len(previous) else 0) for i, b in enumerate(row))
        rows.append(row)
        previous = row
        pos += size
    assert pos == len(data)
    return rows


def dynamic(data, offset_word):
    offset = int.from_bytes(data[offset_word:offset_word + 32], 'big')
    size = int.from_bytes(data[offset:offset + 32], 'big')
    result = data[offset + 32:offset + 32 + size]
    assert len(result) == size
    return result


def verify(directory):
    report = json.loads((directory / 'evm.json').read_text())
    manifest = json.loads((directory / 'frame-manifest.json').read_text())
    assert report['pass'] and manifest['pass'] and report['exit']['reached'] and report['ownedRuntimeStopped']
    assert report['executedTics'] == report['verifiedTics'] == 279
    native = states(gzip.decompress((ROOT / 'artifacts/speedrun-e1m1/native-states.delta.bin.gz').read_bytes()), True)
    actual = states(gzip.decompress((directory / 'evm.states.bin.gz').read_bytes()))
    assert len(native) == len(actual) == 280 and native == actual
    assert report['actualStateStreamSha256'] == '82ea9cd129ba41274de70fe4b2e829d9e5c47ac3f18c5b6f9456183a7d339010'
    demo = (ROOT / 'artifacts/speedrun-e1m1/e1m1-easy.lmp').read_bytes()
    assert report['demoSha256'] == sha(demo)
    assert report['originalCommandBytesSha256'] == sha(demo[13:13 + 279 * 4])
    address = report['deployment']['address']
    replay = json.loads(gzip.decompress((directory / 'evm.replay-receipts.json.gz').read_bytes()))
    captures = json.loads(gzip.decompress((directory / 'evm.capture-receipts.json.gz').read_bytes()))
    observed = []
    for receipt in replay:
        assert receipt['status'] == '0x1'
        for log in receipt['logs']:
            assert log['address'] == address
            data = bytes.fromhex(log['data'][2:])
            tic = int.from_bytes(data[:32], 'big')
            assert dynamic(data, 32) == native[tic]
            observed.append(tic)
    assert observed == list(range(280))
    assert len(captures) == len(manifest['frames']) == report['captureTransactionCount']
    palette = (directory / 'palette.bin').read_bytes()
    assert len(palette) == 768
    assert sha(palette) == manifest['authenticatedPaletteSha256'] == 'fd895921b5d0a394612bb29852ed003d44d69f76dec31c0dc6b5d5fc7d63f7bb'
    expected_tics = list(range(manifest['sampleEvery'], 279, manifest['sampleEvery'])) + [279]
    assert [f['tic'] for f in manifest['frames']] == expected_tics
    for receipt, frame in zip(captures, manifest['frames']):
        assert receipt['status'] == '0x1' and receipt['transactionHash'] == frame['transactionHash']
        assert int(receipt['gasUsed'], 16) == frame['gas']
        assert len(receipt['logs']) == 2 and all(log['address'] == address for log in receipt['logs'])
        log = next(log for log in receipt['logs'] if log['topics'][0] == FRAME_TOPIC)
        assert int(log['topics'][1], 16) == int(frame['frameId'])
        assert int(log['topics'][2], 16) == frame['tic']
        data = bytes.fromhex(log['data'][2:])
        assert int.from_bytes(data[:32], 'big') == 320 and int.from_bytes(data[32:64], 'big') == 200
        pixels = dynamic(data, 64)
        assert pixels == (directory / frame['file']).read_bytes()
        assert len(pixels) == 64000 and sha(pixels) == frame['indexed8Sha256']
        proof = next(log for log in receipt['logs'] if log['topics'][0] != FRAME_TOPIC)
        proof_bytes = bytes.fromhex(proof['data'][2:])
        assert proof_bytes[:32].hex() == frame['beforeStateSha256'] == sha(native[frame['tic']])
        assert proof_bytes[32:64].hex() == frame['renderedMemoryStateSha256']
        assert frame['savedStateUnchanged'] and frame['validAfter'] == frame['validBefore'] + 1
        assert frame['mappedAfter'] >= frame['mappedBefore']
        png = directory / frame['png']
        rgb = b''.join(palette[p * 3:p * 3 + 3] for p in pixels)
        assert Image.open(png).convert('RGB').tobytes() == rgb
        assert sha(rgb) == frame['rgbSha256'] and sha(png.read_bytes()) == frame['pngSha256']
    for file, digest in report['sourceHashes'].items():
        assert sha((ROOT / file).read_bytes()) == digest, file + ' executed source changed'
    assert sha((directory / 'evm.capture-receipts.json.gz').read_bytes()) == report['captureReceiptsSha256']
    assert sha((directory / 'evm.replay-receipts.json.gz').read_bytes()) == report['replayReceiptsSha256']
    assert sum(f['gas'] for f in manifest['frames']) == report['totalCaptureGas']
    assert sum(f['durationTics'] for f in manifest['frames']) == 279
    media = manifest['media']
    mp4 = directory / media['mp4']
    assert sha(mp4.read_bytes()) == media['mp4Sha256']
    assert sha((directory / media['contactSheet']).read_bytes()) == media['contactSheetSha256']
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-count_frames',
        '-select_streams', 'v:0', '-show_streams', '-show_format', '-of', 'json', str(mp4)]))
    stream = probe['streams'][0]
    assert (stream['width'], stream['height'], stream['sample_aspect_ratio'], stream['display_aspect_ratio']) == (1280, 800, '5:6', '4:3')
    assert stream['avg_frame_rate'] == '35/1' and int(stream['nb_read_frames']) == 279
    assert abs(float(probe['format']['duration']) - 279 / 35) < 0.00001
    result = dict(pass_=True, gameplayWorlds=280, originalTics=279, genuineExit=True,
        standardEVMFrames=len(captures), pngPaletteExpansionExact=True, encodedFrames=279,
        durationSeconds=float(probe['format']['duration']), sampleAspectRatio='5:6', displayAspectRatio='4:3',
        frameManifestSha256=sha((directory / 'frame-manifest.json').read_bytes()),
        totalCaptureGas=report['totalCaptureGas'], totalReplayGas=report['totalReplayGas'])
    (directory / 'video-verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    verify(parser.parse_args().directory.resolve())
