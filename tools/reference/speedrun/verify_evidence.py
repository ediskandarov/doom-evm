#!/usr/bin/env python3
"""Offline receipt/state/tape verification of the preserved E1M1 experiment."""
import gzip
import json
from pathlib import Path
import struct
import sys

from replay import ROOT, sha, decode, delta_encode
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'gameplay'))
from verify import delta_decode

base = ROOT / 'artifacts/speedrun-e1m1'
read = lambda name: json.loads((base / name).read_text())
demo = (base / 'e1m1-easy.lmp').read_bytes()
header, tape, marker, footer = decode(demo)
assert read('tape.json') == dict(header=header, ticRate=35, commands=tape)
commands = ''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n" for r in tape).encode()
assert commands == (base / 'commands.txt').read_bytes()
native = read('native-result.json')
recheck = read('native-recheck-result.json')
evm = read('evm-result.json')
assert native['exitReached'] and native['allProfilesExact'] and evm['pass']
assert native['executedTics'] == evm['executedTics'] == evm['verifiedTics'] == 279
assert b''.join(commands.splitlines(keepends=True)[:279]) == (base / 'level-commands.txt').read_bytes()
assert native['commandsSha256'] == recheck['commandsSha256'] == sha(commands)
assert all(r['exitEvents'] == [[279, 279, 6, 0, 407]] for r in native['profiles'] + recheck['profiles'])
native_stream = delta_decode(gzip.decompress((base / 'native-states.delta.bin.gz').read_bytes()))
evm_stream = delta_decode(gzip.decompress((base / 'evm-states.delta.bin.gz').read_bytes()))
assert native_stream == evm_stream
assert sha(evm_stream) == native['statesSha256'] == recheck['statesSha256'] == evm['actualStateStreamSha256']
assert len(evm_stream) == 28562808
states = []
pos = 0
while pos < len(native_stream):
    size = struct.unpack_from('>I', native_stream, pos)[0]
    pos += 4
    states.append(native_stream[pos:pos + size])
    pos += size
assert pos == len(native_stream) and len(states) == 280
for row, state in zip(read('native-state-hashes.json'), states):
    assert row['sha256'] == sha(state) and row['bytes'] == len(state)

receipts = json.loads(gzip.decompress((base / 'evm-replay-receipts.json.gz').read_bytes()))
deployment = json.loads(gzip.decompress((base / 'evm-deployment-receipts.json.gz').read_bytes()))
assert len(receipts) == 57 and len(deployment) == 1756
assert sha((base / 'evm-replay-receipts.json.gz').read_bytes()) == evm['replayReceiptsSha256']
assert sha((base / 'evm-deployment-receipts.json.gz').read_bytes()) == evm['deploymentReceiptsSha256']
assert all(r['status'] == '0x1' for r in receipts + deployment)
assert receipts[0]['transactionHash'] == evm['startup']['transaction']
assert int(receipts[0]['gasUsed'], 16) == evm['startup']['gas']
assert deployment[-1]['transactionHash'] == evm['deployment']['transaction']
assert sum(int(r['gasUsed'], 16) for r in deployment) == evm['deployment']['totalGas']
assert all(r['contractAddress'] for r in deployment)
assert len({r['contractAddress'] for r in deployment}) == len(deployment)
address = evm['deployment']['address']
observations = []
topic = receipts[0]['logs'][0]['topics']
for receipt in receipts:
    for log in receipt['logs']:
        assert log['address'] == address and log['topics'] == topic and len(topic) == 1
        data = bytes.fromhex(log['data'][2:])
        tic = int.from_bytes(data[:32], 'big')
        offset = int.from_bytes(data[32:64], 'big')
        size = int.from_bytes(data[offset:offset + 32], 'big')
        state = data[offset + 32:offset + 32 + size]
        assert len(state) == size and state == states[tic]
        observations.append(tic)
assert observations == list(range(280)), 'Every actual receipt observation must match original C'
for r, metric in zip(receipts[1:], evm['replayTransactions']):
    assert r['transactionHash'] == metric['hash']
    assert int(r['gasUsed'], 16) == metric['gas']
    assert len(r['logs']) == metric['tics']
    assert int.from_bytes(bytes.fromhex(r['logs'][0]['data'][2:])[:32], 'big') == metric['firstTic']
assert sum(int(r['gasUsed'], 16) for r in receipts[1:]) == evm['totalReplayGas'] == 21203677822
assert evm['replayTransactionCount'] == 56
assert evm['gasPerExecutedTic'] == evm['totalReplayGas'] / 279
final = struct.unpack('>11i', states[-1][:44])
assert final[1:7] == (279, 279, 143, 0, 6, 0)
assert sha(states[-1]) == evm['exit']['finalStateSha256']

# The EVM run predates adding only native footer checksum/manifest metadata.
# Every EVM library and runner must still match the recorded executed source.
# Both native builds must have identical generated input/exit observer sources.
for file, digest in evm['sourceHashes'].items():
    if file != 'tools/reference/speedrun/replay.py':
        assert sha((ROOT / file).read_bytes()) == digest, file + ' executed-source drift'
assert read('native-recheck-O2-build.json')['speedrunBuilderSha256'] == sha((ROOT / 'tools/reference/speedrun/replay.py').read_bytes())
for profile in ['O2', 'O0', 'sanitize']:
    before, after = read('native-' + profile + '-build.json'), read('native-recheck-' + profile + '-build.json')
    for key in ['generatedReplayHostSha256', 'generatedReplaySwitchSha256', 'sources']:
        assert before[key] == after[key], key
assert evm['ownedRuntimeStopped']
print(json.dumps(dict(pass_=True, originalDemoBytes=len(demo), decodedTics=len(tape),
    nativeProfiles=4, nativeRecheckProfiles=4, exactReceiptWorlds=len(observations),
    resourceAndProbeReceipts=len(deployment), startupReceipts=1, replayReceipts=56,
    totalReplayGas=evm['totalReplayGas'], fullStateStreamSha256=sha(evm_stream)), indent=2))
