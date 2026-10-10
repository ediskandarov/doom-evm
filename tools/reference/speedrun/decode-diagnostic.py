#!/usr/bin/env python3
"""Decode the error-only sample and follow CURRENT zone links, not retired headers."""
import argparse
import hashlib
import json
from pathlib import Path


def decode(report):
    data = bytes.fromhex(report['renderFailure']['rpcError']['data'][2:])
    payload = data[4:]
    word = lambda p, i: int.from_bytes(p[i*32:(i+1)*32], 'big')
    names = 'index logicalLength sourceOffset tailLength knownLength known sourceHash x yl yh row blockId blockBase blockSize zoneLength owner ledgerOffset'.split()
    result = {n: (payload[i*32:(i+1)*32].hex() if n in ['sourceHash', 'known'] else word(payload, i))
              for i, n in enumerate(names)}
    at = result['ledgerOffset']
    ledger = payload[at+32:at+32+word(payload, at//32)]
    assert len(ledger) == word(payload, at//32)
    zone = ledger[word(ledger, 0):]
    at = word(zone, 5)
    capacity = word(zone, at//32)
    blocks = zone[at+32:]
    fields = 'offset size prev next owner id tag allocated idKnown payloadExtent'.split()
    block = lambda i: dict(blockId=i, **{k: word(blocks, i*10+j) for j, k in enumerate(fields)})
    physical = result['blockBase'] + 40 + result['index']
    identifier = block(0)['next']
    count = word(zone, 2)
    visited = set()
    sample = None
    while identifier:
        assert identifier not in visited and identifier < count
        visited.add(identifier)
        current = block(identifier)
        if current['offset'] <= physical < current['offset'] + current['size']:
            assert sample is None
            sample = dict(**current, relative=physical-current['offset'])
        identifier = current['next']
    assert sample
    result.update(selector=data[:4].hex(), requestedLength=1, physicalOffset=physical,
                  sampleBlock=sample, zoneBlockCount=count, zoneArrayLength=capacity,
                  deterministicInitialization=bool(word(zone, 3)), canonicalPointerHighBytes=bool(word(zone, 4)),
                  ledgerSha256=hashlib.sha256(ledger).hexdigest(), errorDataSha256=hashlib.sha256(data).hexdigest())
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('report', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = decode(json.loads(args.report.read_text()))
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
