#!/usr/bin/env python3
"""Reuse two accepted native idle states without rewriting inherited M3 fixtures."""
import argparse,gzip,hashlib,json,pathlib,struct
ROOT=pathlib.Path(__file__).resolve().parents[3]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');a=ap.parse_args()
    source=ROOT/'src/support/GameplayProbe.sol';text=source.read_text()
    imports=text[text.index('import {\n'):text.index('/// @notice')].replace('"../doom/','"../../src/doom/')
    code='// SPDX-License-Identifier: GPL-2.0-only\n// Generated observation-only copy of accepted GameplayProbe; see legacy.py.\npragma solidity 0.8.37;\n'+imports+'\nlibrary GameflowLegacySnapshot {\n    error InvalidScenario();\n'+text[text.index('    struct Words'):]
    code=code.replace('function observe(GameState memory s) private','function observe(GameState memory s) internal')
    fixture=ROOT/'test/fixtures/gameplay/idle/states.delta.bin.gz';data=gzip.decompress(fixture.read_bytes());pos=0;previous=b'';states=[]
    for i in range(2):
        size=struct.unpack_from('>I',data,pos)[0];pos+=4
        state=bytes(data[pos+j]^(previous[j] if j<len(previous) else 0) for j in range(size));pos+=size
        states.append(state);previous=state
    manifest=dict(scope='Two unchanged accepted native DSG1 E1M1 medium-skill idle snapshots, setup and tic 1 before rendering; full serialized gameplay state, no pixel claim',
        upstreamFixture=str(fixture.relative_to(ROOT)),upstreamFixtureSha256=sha(fixture.read_bytes()),serializerSourceSha256=sha(source.read_bytes()),
        resourceIdentity=json.loads((ROOT/'test/fixtures/gameplay/manifest.json').read_text())['resourceIdentity'],
        states=[dict(tic=i,bytes=len(b),sha256=sha(b)) for i,b in enumerate(states)])
    outputs={'test/unit/GameflowLegacySnapshot.sol':code.encode(),'test/fixtures/phase4_gameflow/legacy.json':(json.dumps(manifest,indent=2)+'\n').encode()}
    for i,b in enumerate(states):outputs[f'test/fixtures/phase4_gameflow/legacy-idle-{i}.bin']=b
    for name,b in outputs.items():
        p=ROOT/name
        if a.check:assert p.read_bytes()==b,'stale '+name
        else:p.write_bytes(b)
    print('PASS unchanged M3 fixture/serializer provenance, full native setup and first-tic states')
if __name__=='__main__':main()
