#!/usr/bin/env python3
"""Generate and check the exact persisted-root archive schema with pinned solc.

Only storageLayout is requested; no expensive engine bytecode compilation.
Nodes describe fixed storage words plus dynamic descendants. Root slots are
obtained from Solidity storage references at runtime, never copied from a build.
"""
import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TARGET = ROOT / 'src/evm/SaveSchema.sol'


def generate():
    sources = {str(p.relative_to(ROOT)): {'content': p.read_text()}
               for p in sorted((ROOT / 'src').rglob('*.sol'))}
    request = {'language': 'Solidity', 'sources': sources, 'settings': {
        'outputSelection': {'src/evm/Doom.sol': {'Doom': ['storageLayout']},
                            'src/evm/Doom2.sol': {'Doom2': ['storageLayout']}}}}
    with tempfile.TemporaryFile(mode='w+') as inp, tempfile.TemporaryFile(mode='w+') as out:
        json.dump(request, inp); inp.seek(0)
        process = subprocess.run([str(ROOT / '.toolchain/bin/solc'), '--standard-json'],
                                 stdin=inp, stdout=out, stderr=subprocess.PIPE, cwd=ROOT)
        out.seek(0); result = json.load(out)
    errors = [e for e in result.get('errors', []) if e['severity'] == 'error']
    assert process.returncode == 0 and not errors, errors
    layout = result['contracts']['src/evm/Doom.sol']['Doom']['storageLayout']
    other = result['contracts']['src/evm/Doom2.sol']['Doom2']['storageLayout']
    types = layout['types']; order = []; ids = {}

    def visit(t):
        if t in ids: return ids[t]
        ids[t] = len(order); order.append(t)
        obj = types[t]
        if obj['encoding'] == 'mapping': raise ValueError('Mappings require a separate bounded schema')
        if 'members' in obj:
            for m in obj['members']: visit(m['type'])
        elif 'base' in obj: visit(obj['base'])
        return ids[t]

    names = ['gameState', 'uiState', 'inputRuntime', 'episodeState']
    roots = {n: next(x['type'] for x in layout['storage'] if x['label'] == n) for n in names}
    for t in roots.values(): visit(t)
    # Descriptor: kind u8, byteWidth u16, fixedWords u16, childCount u16,
    # children [relativeSlot u16, node u16]. Array nodes have one element child.
    data = bytearray(); offsets = []; records = []
    def dynamic(t):
        obj=types[t]
        if obj['encoding'] != 'inplace': return True
        if 'members' in obj: return any(dynamic(m['type']) for m in obj['members'])
        if 'base' in obj: return dynamic(obj['base'])
        return False
    for t in order:
        obj=types[t]; width=int(obj['numberOfBytes']); children=[]; kind=0; fixed=(width+31)//32
        if obj['encoding']=='bytes': kind=1; fixed=1
        elif obj['encoding']=='dynamic_array': kind=2; fixed=1; children=[(0,ids[obj['base']])]
        elif 'members' in obj:
            children=[(int(m['slot']),ids[m['type']]) for m in obj['members'] if dynamic(m['type'])]
        elif 'base' in obj:
            kind=3; children=[(width//int(types[obj['base']]['numberOfBytes']),ids[obj['base']])]
        offsets.append(len(data)); data += bytes([kind])+width.to_bytes(2,'big')+fixed.to_bytes(2,'big')+len(children).to_bytes(2,'big')
        for slot,node in children: data+=slot.to_bytes(2,'big')+node.to_bytes(2,'big')
        records.append({'id':ids[t],'label':obj['label'],'kind':kind,'byteWidth':width,'fixedWords':fixed,'children':[list(c) for c in children]})
    # Verify identical type structure in both production adapters despite AST IDs/root offsets.
    labels={o['label']:o for o in other['types'].values()}
    for t in order:
        obj=types[t]; rhs=labels[obj['label']]
        assert obj['encoding']==rhs['encoding'] and obj['numberOfBytes']==rhs['numberOfBytes']
        if 'members' in obj:
            assert [(m['label'],m['slot'],m['offset'],types[m['type']]['label']) for m in obj['members']]==[
                (m['label'],m['slot'],m['offset'],other['types'][m['type']]['label']) for m in rhs['members']]
    blob=b''.join(x.to_bytes(2,'big') for x in offsets)+data
    text='''// SPDX-License-Identifier: GPL-2.0-only
pragma solidity 0.8.37;

/// @notice Generated pinned-solc persisted-root storage schema; not gameplay logic.
/// @dev Regenerate/check with tools/reference/save_load/schema.py. IDs/offsets are
/// descriptor-local. Actual root storage slots come from typed .slot references.
library SaveSchema {
'''
    for n,t in roots.items(): text+=f'    uint16 internal constant {n.upper()} = {ids[t]};\n'
    text+=f'    uint16 internal constant NODES = {len(order)};\n'
    text+=f'    bytes internal constant DATA = hex"{blob.hex()}";\n'
    text+='}\n'
    return text, {'schemaVersion':1,'generator':'pinned-solc storageLayout','roots':{
        n:ids[t] for n,t in roots.items()},'nodes':records,'sha256':hashlib.sha256(blob).hexdigest()}


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    text,manifest=generate()
    path=ROOT/'artifacts/save-load/schema.json'
    if args.check:
        assert TARGET.read_text()==text, 'SaveSchema.sol drift; inspect schema migration before regenerating'
        assert json.loads(path.read_text())==manifest, 'schema manifest drift'
        print('PASS exact Doom/Doom2 persisted-root schema',len(manifest['nodes']),'nodes')
    else:
        TARGET.write_text(text);path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(manifest,indent=2)+'\n')
        print('Generated',TARGET,len(manifest['nodes']),'nodes')
