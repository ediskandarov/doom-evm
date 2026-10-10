#!/usr/bin/env python3
"""Nine-map resource oracle; original P_Load*/R_Data bodies, no gameplay startup."""
import argparse, importlib.util, json, pathlib, re, struct, tempfile
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('data_reference', HERE.parent/'phase2_data/reference.py')
data = importlib.util.module_from_spec(spec); spec.loader.exec_module(data)
ref = data.ref
MAPS = [f'E1M{i}' for i in range(1, 10)]

def extract(file, name, result):
    text = (ref.SOURCE/file).read_text()
    match = re.search(r'\n'+re.escape(result)+r'\s+'+name+r'\s*\(', text)
    assert match, name
    start = match.start()+1; end = text.index('{', match.end())+1; depth = 1
    while depth:
        if text[end] == '{': depth += 1
        elif text[end] == '}': depth -= 1
        end += 1
    body = text[start:end]
    return body, dict(file=file, function=name, startLine=text[:start].count('\n')+1,
                     endLine=text[:end].count('\n')+1, sha256=ref.sha(body.encode()))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wad', type=pathlib.Path, default=ROOT/'artifacts/local/freedoom/freedoom1.wad')
    ap.add_argument('--output', type=pathlib.Path, default=ROOT/'artifacts/local/wad/episode-native')
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    assert ref.sha(args.wad.read_bytes()) == json.loads((ROOT/'tools/wad/freedoom.lock.json').read_text())['wadSha256']
    assert ref.invoke(['git', '-C', str(ref.SOURCE), 'rev-parse', 'HEAD']).strip() == ref.UPSTREAM
    assert ref.invoke(['clang', '--version']).splitlines()[:2] == [ref.VERSION, 'Target: '+ref.TARGET]
    for name, pin in data.PINS.items(): assert ref.sha((ref.SOURCE/name).read_bytes()) == pin, name
    units = []; extractions = []
    for file, name, result in data.FUNCTIONS + [('p_setup.c', 'P_LoadBlockMap', 'void')]:
        body, record = extract(file, name, result); units.append(body); extractions.append(record)
    # Reuse the frozen host ABI/disk adapter and native emission format, parameterizing only map selection.
    compat = (HERE.parent/'phase2_data/compat.h').read_text()
    disk = (ref.SOURCE/'doomdata.h').read_text()
    end = disk.index('} mapthing_t;') + len('} mapthing_t;')
    start = disk.rfind('typedef struct', 0, end)
    thing_type = disk[start:end]
    compat += '\n'+thing_type+'\ntypedef char mapthing_disk_size_must_be_10[(sizeof(mapthing_t)==10)?1:-1];\n'
    compat += '\nstatic short *blockmaplump,*blockmap; static fixed_t bmaporgx,bmaporgy; static int bmapwidth,bmapheight; static void **blocklinks;\n'
    driver = (HERE.parent/'phase2_data/driver.c').read_text()
    assert driver.count('W_GetNumForName("E1M1")') == 1
    driver = driver.replace('W_GetNumForName("E1M1")', 'W_GetNumForName(selected_map)')
    driver = '#define main inherited_driver_main\n'+driver+'\n#undef main\n'
    source = '#include "compat.h"\nstatic char *selected_map;\n'+'\n'.join(units)+'\n'+driver+'\n'+(HERE/'driver.c').read_text()
    args.output.mkdir(parents=True, exist_ok=True)
    all_runs = {}
    with tempfile.TemporaryDirectory(prefix='doom-episode-resources-') as td:
        tmp = pathlib.Path(td); (tmp/'oracle.c').write_text(source); (tmp/'compat.h').write_text(compat)
        for profile in ['O0', 'O2', 'sanitize']:
            flags = [('-O0' if profile == 'O0' and f == '-O2' else f) for f in ref.FLAGS]
            if profile == 'sanitize': flags += ['-fsanitize=undefined', '-fno-sanitize=shift', '-fno-sanitize-recover=all']
            ref.invoke(['clang', *flags, '-I'+str(tmp), str(tmp/'oracle.c'), '-o', str(tmp/profile)])
            folder = tmp/(profile+'-output'); folder.mkdir()
            ref.invoke([str(tmp/profile), str(args.wad), str(folder)])
            all_runs[profile] = {p.name: p.read_bytes() for p in folder.iterdir()}
        assert all_runs['O0'] == all_runs['O2'] == all_runs['sanitize'], 'Native profiles disagree'
        for name, payload in all_runs['O2'].items(): (args.output/name).write_bytes(payload)
    metadata = dict(schemaVersion=1, goal='4.7a', upstreamCommit=ref.UPSTREAM, wadSha256=ref.sha(args.wad.read_bytes()),
                    maps=MAPS, compiler=ref.VERSION, target=ref.TARGET, flags=ref.FLAGS,
                    profiles=['O0', 'O2', 'UBSan-except-shift'], extractions=extractions,
                    diskTypes=[dict(file='doomdata.h', type='mapthing_t', startLine=disk[:start].count('\n')+1, endLine=disk[:end].count('\n')+1, sha256=ref.sha(thing_type.encode()))],
                    sources={f: ref.sha((ref.SOURCE/f).read_bytes()) for f in data.PINS},
                    harness={str(p.relative_to(ROOT)): ref.sha(p.read_bytes()) for p in [HERE/'reference.py', HERE/'driver.c', HERE.parent/'phase2_data/compat.h', HERE.parent/'phase2_data/driver.c']},
                    generatedSourceSha256=ref.sha(source.encode()),
                    outputs={n: dict(bytes=len(b), sha256=ref.sha(b)) for n, b in sorted(all_runs['O2'].items())},
                    audit=['Original negative signed shifts in map/sprite/blockmap loading are pinned-profile extensions; UBSan shift checks disabled in this mixed resource run, other undefined checks enabled.',
                           'Reused Phase 2 host adapter: 64-bit runtime pointers, original 16/32-bit disk records, immutable W_CacheLumpNum input, Z_Free no-op; no gameplay spawning or P_SetupLevel execution.',
                           'THINGS are signed mapthing disk words, including every entry regardless of skill/type. BLOCKMAP uses verbatim P_LoadBlockMap; REJECT retains raw W_CacheLumpNum bytes.',
                           'R_InitTextures is the existing explicit disk/allocator adapter. Original texture name resolution, lookup/composite and flat/sprite initialization bodies are extracted verbatim.'])
    target = ROOT/'test/fixtures/phase4_episode/native.json'
    encoded = (json.dumps(metadata, indent=2)+'\n').encode()
    if args.check: assert target.read_bytes() == encoded, 'Native evidence drift'
    else: target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(encoded)
    print(json.dumps(dict(pass_=True, maps=9, nativeProfiles=metadata['profiles'], files=len(metadata['outputs']))))

if __name__ == '__main__': main()
