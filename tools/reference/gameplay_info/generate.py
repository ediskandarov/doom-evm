#!/usr/bin/env python3
"""Export all original gameplay tables; action pointers become stable symbolic IDs."""
import argparse
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import reference as ref

HERE = Path(__file__).resolve().parent
FIELDS = 'doomednum spawnstate spawnhealth seestate seesound reactiontime attacksound painstate painchance painsound meleestate missilestate deathstate xdeathstate deathsound speed radius height mass damage activesound flags raisestate'.split()
STATE_FIELDS = 'sprite frame tics action nextstate misc1 misc2'.split()
WEAPON_FIELDS = 'ammo upstate downstate readystate atkstate flashstate'.split()


def enum_constants(header):
    constants = []
    for body in re.findall(r'typedef\s+enum\s*\{(.*?)\}\s*\w+\s*;', header, re.S):
        body = re.sub(r'/\*.*?\*/|//[^\n]*', '', body, flags=re.S)
        value = 0
        for item in body.split(','):
            name = item.strip()
            if not name:
                continue
            assert re.fullmatch(r'\w+', name), name
            constants.append((name, value))
            value += 1
    return constants


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    assert ref.invoke(['git', '-C', str(ref.SOURCE), 'rev-parse', 'HEAD']).strip() == ref.UPSTREAM
    ref.invoke(['git', '-C', str(ref.SOURCE), 'diff', '--exit-code', 'HEAD', '--'])
    assert ref.invoke(['clang', '--version']).splitlines()[:2] == [ref.VERSION, 'Target: ' + ref.TARGET]
    actions = re.findall(r'void\s+(A_\w+)\s*\(\s*\);', (ref.SOURCE/'info.c').read_text())
    assert len(actions) == len(set(actions))
    action_declarations = '\n'.join('void ' + a + '(void);' for a in actions)
    action_lookup = '\n'.join(f'if (p == (actionf_v){a}) return {i};' for i, a in enumerate(actions, 1))
    exporter = '''#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "info.h"
#include "d_items.h"
''' + action_declarations + '''
static void word(int32_t v) { uint32_t u=(uint32_t)v; unsigned char b[4]={u>>24,u>>16,u>>8,u}; if(fwrite(b,1,4,stdout)!=4) abort(); }
static int action(actionf_v p) { if(!p) return 0;
''' + action_lookup + '''
abort(); }
int main(void) {
word(NUMSTATES); word(NUMMOBJTYPES); word(NUMWEAPONS);
for(int i=0;i<NUMSTATES;i++) { state_t *s=states+i;
''' + ' '.join('word(' + ('action(s->action.acv)' if f == 'action' else 's->' + f) + ');' for f in STATE_FIELDS) + ''' }
for(int i=0;i<NUMMOBJTYPES;i++) { mobjinfo_t *m=mobjinfo+i;
''' + ' '.join('word(m->' + f + ');' for f in FIELDS) + ''' }
for(int i=0;i<NUMWEAPONS;i++) { weaponinfo_t *w=weaponinfo+i;
''' + ' '.join('word(w->' + f + ');' for f in WEAPON_FIELDS) + ''' }
return 0; }
'''
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        (temp/'export.c').write_text(exporter)
        (temp/'actions.c').write_text('#include <stdlib.h>\n' + '\n'.join('void ' + a + '(void) { abort(); }' for a in actions))
        outputs = []
        for opt, sanitizers in [('-O0', []), ('-O2', []), ('-O2', ['-fsanitize=address,undefined', '-fno-sanitize-recover=all'])]:
            subprocess.run(['clang', '-std=c99', opt, *sanitizers, '-I'+str(ref.SOURCE), str(temp/'export.c'), str(ref.SOURCE/'info.c'), str(ref.SOURCE/'d_items.c'), str(temp/'actions.c'), '-o', str(temp/'export')], check=True, capture_output=True)
            outputs.append(subprocess.check_output([str(temp/'export')]))
        assert outputs[0] == outputs[1] == outputs[2]
    raw = outputs[0]
    states, mobjs, weapons = struct.unpack_from('>III', raw)
    assert weapons == 9 and len(raw) == 12 + states*28 + mobjs*92 + weapons*24
    state_data = raw[12:12+states*28]
    mobj_data = raw[12+states*28:12+states*28+mobjs*92]
    weapon_data = raw[-weapons*24:]
    source = '''// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
// Generated from original info.c/d_items.c, including real action IDs and state transitions.
pragma solidity 0.8.37;
import {GameDefinitions, StateDef, MobjInfo, WeaponInfo} from "./p_game_state.sol";
/// @custom:source linuxdoom-1.10/info.c, info.h, d_items.c at ''' + ref.UPSTREAM + '''
library P_Info {
'''
    for name, value in enum_constants((ref.SOURCE/'info.h').read_text()):
        source += f'uint32 internal constant {name} = {value};\n'
    for i, action in enumerate(actions, 1):
        source += f'uint32 internal constant {action} = {i};\n'
    source += 'function load() internal pure returns (GameDefinitions memory d) {\n'
    source += f'bytes memory s=hex"{state_data.hex()}"; bytes memory m=hex"{mobj_data.hex()}"; bytes memory w=hex"{weapon_data.hex()}";\n'
    source += f'd.states=new StateDef[]({states}); d.mobjinfo=new MobjInfo[]({mobjs});\n'
    source += 'for(uint256 i;i<d.states.length;++i) {\n'
    for j, field in enumerate(STATE_FIELDS):
        value = f'word(s,i*28+{j*4})'
        if field in ('tics', 'misc1', 'misc2'):
            value = 'int32(' + value + ')'
        source += f'd.states[i].{field}={value};\n'
    source += '} for(uint256 i;i<d.mobjinfo.length;++i) {\n'
    for j, field in enumerate(FIELDS):
        source += f'd.mobjinfo[i].{field}=int32(word(m,i*92+{j*4}));\n'
    source += '} for(uint256 i;i<9;++i) {\n'
    for j, field in enumerate(WEAPON_FIELDS):
        value = f'word(w,i*24+{j*4})'
        if field == 'ammo':
            value = 'int32(' + value + ')'
        source += f'd.weaponinfo[i].{field}={value};\n'
    source += '} }\nfunction word(bytes memory b,uint256 o) private pure returns(uint32 v) { for(uint256 j;j<4;++j) v=(v<<8)|uint8(b[o+j]); }\n}\n'
    source = ref.invoke([str(ref.ROOT/'.toolchain/bin/forge'), 'fmt', '--root', str(ref.ROOT), '--raw', '-'], input=source).encode()
    metadata = dict(upstreamCommit=ref.UPSTREAM, compiler=ref.VERSION, target=ref.TARGET,
                    counts=dict(states=states, mobjTypes=mobjs, weapons=weapons, actions=len(actions)),
                    encoding='big-endian u32; original signed fields retain two-complement bits; action IDs declaration order+1, zero NULL',
                    actionIds={a:i for i,a in enumerate(actions,1)},
                    sources={name:ref.sha((ref.SOURCE/name).read_bytes()) for name in ['info.c', 'info.h', 'd_items.c', 'd_items.h', 'doomdef.h', 'doomtype.h', 'd_think.h']},
                    exporterSha256=ref.sha(exporter.encode()), generatorSha256=ref.sha(Path(__file__).read_bytes()),
                    sha256=ref.sha(raw), soliditySha256=ref.sha(source), nativeAgreement='O0/O2/ASan+UBSan exact')
    artifacts = {ref.ROOT/'src/doom/p_info.sol':source, ref.ROOT/'test/fixtures/gameplay_info/tables.bin':raw,
                 ref.ROOT/'test/fixtures/gameplay_info/manifest.json':(json.dumps(metadata,indent=2)+'\n').encode()}
    for path, data in artifacts.items():
        if args.check:
            assert path.read_bytes() == data, 'stale ' + str(path)
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    print(f'PASS complete original gameplay tables: {states} states, {mobjs} mobj types, {weapons} weapons, {len(actions)} actions; O0/O2/ASan/UBSan exact')


if __name__ == '__main__':
    main()
