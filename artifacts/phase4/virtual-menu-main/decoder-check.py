#!/usr/bin/env python3
"""Decode actual preserved diagnostic evidence and both extended ABI booleans."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('diagnostic',ROOT/'tools/reference/speedrun/decode-diagnostic.py')
decoder=importlib.util.module_from_spec(spec)
spec.loader.exec_module(decoder)
word=lambda p,i:int.from_bytes(p[i*32:(i+1)*32],'big')
encode=lambda n:n.to_bytes(32,'big')


def check(path):
    report=json.loads(path.read_text())
    before=decoder.decode(report)
    assert not before['experimentalVirtualPointers']
    assert before['physicalOffset']==12785689 and before['sampleBlock']['relative']==25
    raw=bytes.fromhex(report['renderFailure']['rpcError']['data'][2:])
    payload=raw[4:];at=word(payload,16)
    ledger=payload[at+32:at+32+word(payload,at//32)]
    zone_offset=word(ledger,0);zone=ledger[zone_offset:]
    assert word(zone,5)>=7*32
    for bit in [0,1]:
        extended=bytearray(zone[:5*32]+encode(bit)+zone[5*32:])
        extended[6*32:7*32]=encode(word(zone,5)+32)
        extended[7*32:8*32]=encode(word(zone,6)+32)
        ledger2=ledger[:zone_offset]+extended
        payload2=payload[:at]+encode(len(ledger2))+ledger2
        adapted=copy.deepcopy(report)
        adapted['renderFailure']['rpcError']['data']='0x'+(raw[:4]+payload2).hex()
        after=decoder.decode(adapted)
        assert after['experimentalVirtualPointers']==bool(bit)
        for key,value in before.items():
            if key not in ['experimentalVirtualPointers','ledgerSha256','errorDataSha256']:
                assert after[key]==value,key
    result=dict(pass_=True,oldABI=True,newABIFalse=True,newABITrue=True,
                diagnosticEvidenceSha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                physicalOffset=before['physicalOffset'],sampleBlock=before['sampleBlock'],
                scope='Actual preserved error plus independently encoded extended ZoneState ABI, not a new EVM failure.')
    out=ROOT/'artifacts/local/virtual-menu-main/decoder-result.json'
    out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('diagnostic',type=Path)
    check(ap.parse_args().diagnostic)
