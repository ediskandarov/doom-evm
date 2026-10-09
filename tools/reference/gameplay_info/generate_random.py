#!/usr/bin/env python3
"""Pin the original RNG table and native wrap/reset vectors for both streams."""
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    original = (ref.SOURCE/'m_random.c').read_bytes()
    assert ref.invoke(['git', '-C', str(ref.SOURCE), 'rev-parse', 'HEAD']).strip() == ref.UPSTREAM
    ref.invoke(['git', '-C', str(ref.SOURCE), 'diff', '--exit-code', 'HEAD', '--'])
    assert ref.invoke(['clang', '--version']).splitlines()[:2] == [ref.VERSION, 'Target: ' + ref.TARGET]
    table = bytes(map(int, re.findall(r'\d+', re.search(r'rndtable\[256\]\s*=\s*\{(.*?)\}', original.decode(), re.S)[1])))
    assert len(table) == 256
    exporter = '''#include <stdio.h>
#include <stdint.h>
extern int prndindex, rndindex;
int P_Random(void); int M_Random(void); void M_ClearRandom(void);
static void word(uint32_t v) { unsigned char b[4]={v>>24,v>>16,v>>8,v}; fwrite(b,1,4,stdout); }
int main(void) { M_ClearRandom(); word(1024); for(int i=0;i<1024;i++) {
int p=P_Random(); word(prndindex); word(p);
if(i%3!=0) M_Random(); int m=M_Random(); word(rndindex); word(m);
if(i==511) M_ClearRandom();
} return 0; }
'''
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        (temp/'export.c').write_text(exporter)
        outputs = []
        for opt, sanitizers in [('-O0', []), ('-O2', []), ('-O2', ['-fsanitize=address,undefined', '-fno-sanitize-recover=all'])]:
            subprocess.run(['clang', '-std=c99', opt, *sanitizers, str(temp/'export.c'), str(ref.SOURCE/'m_random.c'), '-o', str(temp/'export')], check=True, capture_output=True)
            outputs.append(subprocess.check_output([str(temp/'export')]))
        assert outputs[0] == outputs[1] == outputs[2]
    raw = outputs[0]
    assert len(raw) == 4 + 1024*16 and struct.unpack_from('>I', raw)[0] == 1024
    source = '''// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 1993-1996 by id Software, Inc.
// Generated original random table; gameplay and miscellaneous streams are independent.
pragma solidity 0.8.37;
import {GameState} from "./p_game_state.sol";
/// @custom:source linuxdoom-1.10/m_random.c at ''' + ref.UPSTREAM + '''
library M_Random {
function P_Random(GameState memory state) internal pure returns(int32) {
state.prndindex=(state.prndindex+1)&255; return int32(uint32(value(state.prndindex))); }
function M_RandomValue(GameState memory state) internal pure returns(int32) {
state.rndindex=(state.rndindex+1)&255; return int32(uint32(value(state.rndindex))); }
function M_ClearRandom(GameState memory state) internal pure { state.rndindex=0;state.prndindex=0; }
function value(uint32 index) internal pure returns(uint8) {
require(index<256,"random index"); uint256 packed;
'''
    for i in range(8):
        source += ('if' if i == 0 else 'else if') + f'(index/32=={i}) packed=0x{table[i*32:(i+1)*32].hex()};\n'
    source += 'return uint8(packed>>((31-index%32)*8)); }\n}\n'
    source = ref.invoke([str(ref.ROOT/'.toolchain/bin/forge'), 'fmt', '--root', str(ref.ROOT), '--raw', '-'], input=source).encode()
    manifest = dict(upstreamCommit=ref.UPSTREAM, compiler=ref.VERSION, target=ref.TARGET,
                    originalSha256=ref.sha(original), tableSha256=ref.sha(table), vectorsSha256=ref.sha(raw),
                    generatorSha256=ref.sha(Path(__file__).read_bytes()), exporterSha256=ref.sha(exporter.encode()),
                    soliditySha256=ref.sha(source), nativeAgreement='O0/O2/ASan+UBSan exact',
                    encoding='u32 count then 1024 big-endian (prndindex,P_Random,rndindex,M_Random) rows; M_Random extra call on i%3!=0; clear after row511',
                    deviation='Library is M_Random; original M_Random function spelled M_RandomValue because Solidity member names cannot duplicate the library name.')
    artifacts = {ref.ROOT/'src/doom/m_random.sol':source,
                 ref.ROOT/'test/fixtures/gameplay_info/random.bin':raw,
                 ref.ROOT/'test/fixtures/gameplay_info/random-manifest.json':(json.dumps(manifest,indent=2)+'\n').encode()}
    for path, data in artifacts.items():
        if args.check:
            assert path.read_bytes() == data, 'stale ' + str(path)
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
    print('PASS original RNG: all 256 table values, 1024 independent-stream/wrap/reset vectors; O0/O2/ASan/UBSan exact')


if __name__ == '__main__':
    main()
