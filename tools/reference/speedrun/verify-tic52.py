#!/usr/bin/env python3
"""Audit the bounded tic52 investigation without claiming full-rate success."""
import gzip
import json
from pathlib import Path
import subprocess
from replay import ROOT, sha, save
from verify_video import states

base = ROOT / 'artifacts/local/speedrun-tic52'
read = lambda p: json.loads((base / p).read_text())
native = read('native-recheck/native-result.json')
sampled = read('sampled/evm.json')
historical = json.loads((ROOT / 'artifacts/speedrun-e1m1-video/recording-result.json').read_text())
reference = states(gzip.decompress((ROOT / 'artifacts/speedrun-e1m1/native-states.delta.bin.gz').read_bytes()), True)
actual = states(gzip.decompress((base / 'sampled/evm.states.bin.gz').read_bytes()))
assert native['allProfilesExact'] and native['executedTics'] == 279
assert native['statesSha256'] == sampled['actualStateStreamSha256']
assert sampled['pass'] and sampled['exit']['reached'] and len(actual) == 280 and actual == reference
assert [(r['tic'], r['indexed8Sha256']) for r in sampled['frames']] == [(r['tic'], r['indexed8Sha256']) for r in historical['frames']]
native_frames = read('native-frames-recheck/native-frames.json')
assert len(native_frames['frames']) == 279 and len(native_frames['profiles']) == 3
divergences = native_frames['divergences']
assert len(divergences) == 1 and divergences[0]['tic'] == 52 and divergences[0]['pixels'] == 1
assert divergences[0]['first'] == [dict(offset=49901, x=301, y=155, O2=73, actual=105)]
expected = {r['tic']: r['indexed8Sha256'] for r in native_frames['frames']}
partial = read('episode-full/evm.json')
assert partial['renderFailure']['tic'] == 52 and [r['tic'] for r in partial['frames']] == list(range(1, 52))
for report in [sampled, partial]:
    for frame in report['frames']:
        assert frame['indexed8Sha256'] == expected[frame['tic']], (report['memoryProfile'] if 'memoryProfile' in report else 'baseline', frame['tic'])
diagnostic = read('diagnostic52/decoded.json')
assert diagnostic['index'] == 265 and diagnostic['logicalLength'] == 238 and diagnostic['requestedLength'] == 1
assert diagnostic['sampleBlock']['relative'] == 25 and diagnostic['sampleBlock']['owner'] == 1553
assert diagnostic['deterministicInitialization'] and diagnostic['canonicalPointerHighBytes']
samples = read('native-sample/sample.json')['profiles']
for row in samples:
    s = row['sample']
    assert s['sample'] == diagnostic['physicalOffset'] and s['sourceOwner'] == diagnostic['owner']
    assert s['sourceBlock']['offset'] == diagnostic['blockBase'] and s['sourceBlock']['size'] == diagnostic['blockSize']
    assert s['sampleBlock']['offset'] == diagnostic['sampleBlock']['offset'] and s['sampleRelative'] == 25
    pointer = int(s['zoneAddress'], 16) + s['sampleBlock']['next']
    assert (pointer >> 8) & 255 == s['value'], 'Original source-written next-pointer byte'

profiles = []
for name in ['strict', 'legacy', 'episode']:
    report = read(name + '-rollback52/evm.json')
    failure = report['renderFailure']
    assert report['memoryProfile'] == name and failure['tic'] == 52
    assert failure['rpcError']['data'] == '0x5b9a48fe' and failure['gas'] < 10_000_000_000
    assert all(failure['rollback'][k] for k in ['allSavedFieldsUnchanged', 'nativeWorldExact', 'frameCounterUnchanged', 'noLogs'])
    assert report['ownedRuntimeStopped'] and report['verifiedTics'] == 52
    captures = json.loads(gzip.decompress((base / (name + '-rollback52/evm.capture-receipts.json.gz')).read_bytes()))
    assert len(captures) == 1 and captures[0]['status'] == '0x0' and not captures[0]['logs']
    assert captures[0]['transactionHash'] == failure['transactionHash']
    assert sha((base / (name + '-rollback52/evm.capture-receipts.json.gz')).read_bytes()) == report['captureReceiptsSha256']
    for file, digest in report['sourceHashes'].items():
        assert sha((ROOT / file).read_bytes()) == digest, file
    profiles.append(dict(name=name, gas=failure['gas'], elapsedMs=failure['elapsedMs'],
                         rollback=failure['rollback'], transactionHash=failure['transactionHash'],
                         startedUTC=report['startedUTC'], endedUTC=report['endedUTC'], runtimeSha256=report['deployment']['runtimeSha256']))

fixture = json.loads((ROOT / 'test/fixtures/speedrun_tic52/manifest.json').read_text())
blob = (ROOT / 'artifacts/local/speedrun-e1m1/wad/resources.bin').read_bytes()
for row in fixture['lumps']:
    data = (ROOT / ('test/fixtures/speedrun_tic52/' + row['name'] + '.bin')).read_bytes()
    assert sha(data) == row['sha256'] and data == blob[row['bundleOffset']:row['bundleOffset']+row['length']]

files = ['sampled/evm.json', 'sampled/video-verification.json', 'sampled/evm.capture-receipts.json.gz',
         'episode-full/evm.json', 'episode-full/evm.capture-receipts.json.gz', 'native-recheck/native-result.json',
         'native-frames-recheck/native-frames.json', 'native-sample/sample.json', 'diagnostic52/evm.json', 'diagnostic52/decoded.json',
         'backing-tests.log', 'backing-tests-recheck.log', 'regression-tests.log', 'episode-tests.log', 'final-build.log']
files += [name + '-rollback52/' + f for name in ['strict', 'legacy', 'episode']
          for f in ['evm.json', 'evm.capture-receipts.json.gz', 'evm.replay-receipts.json.gz', 'evm.deployment-receipts.json.gz']]
tests = {}
for name in ['backing-tests-recheck', 'regression-tests', 'episode-tests']:
    log = (base / (name + '.log')).read_text()
    assert '[FAIL' not in log and '0 failed' in log, name
    tests[name] = log.splitlines()[-1]
report = dict(investigationVerified=True, fullRateSuccess=False, firstUnresolvedTic=52,
              productionEngineChanged=False, nativeGameplaySnapshots=280, genuineExit=True,
              sampledFrameHashesExact=56, nativeMatchingFullRateFramesBeforeFailure=51,
              nativeIndependentFramesPerProfile=279, nativePixelProfileDivergences=divergences,
              diagnosis=diagnostic, memoryProfiles=profiles, focusedForgeResults=tests,
              sampledReplayElapsedMs=sampled['replayElapsedMs'], sampledCaptureGas=sampled['totalCaptureGas'],
              nativeFrameVerificationElapsedSeconds=native_frames['elapsedSeconds'],
              evidenceHashes={p: sha((base / p).read_bytes()) for p in files})
save(base / 'checkpoint.json', report)
print(json.dumps({k: v for k, v in report.items() if k not in ['evidenceHashes', 'diagnosis', 'memoryProfiles']}, indent=2))
