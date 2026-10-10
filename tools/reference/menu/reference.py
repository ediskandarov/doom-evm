#!/usr/bin/env python3
"""Pinned original menu functions/video; immutable UI borrowing, no gameplay zone."""
import argparse, hashlib, json, os, re, shutil, struct, subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
import reference as ref

FUNCTIONS = ['M_DrawMainMenu', 'M_DrawNewGame', 'M_DrawEpisode', 'M_WriteText',
             'M_StringWidth', 'M_StringHeight', 'M_Drawer', 'M_Ticker', 'M_Init',
             'M_StartControlPanel', 'M_ClearMenus', 'M_SetupNextMenu', 'M_StartMessage',
             'M_StopMessage', 'M_NewGame', 'M_Episode', 'M_ChooseSkill', 'M_VerifyNightmare',
             'M_Responder']

def extract(text, name):
    for match in re.finditer(r'\n(?:void|int|boolean)\s+' + name + r'\s*\([^;{]*\)\s*\{', text):
        start = match.start() + 1
        end = match.end()
        depth = 1
        while depth:
            if text[end] == '{': depth += 1
            if text[end] == '}': depth -= 1
            end += 1
        body = text[start:end]
        return body, dict(file='m_menu.c', function=name, startLine=text[:start].count('\n')+1,
                         endLine=text[:end].count('\n')+1, sha256=ref.sha(body.encode()))
    raise ValueError(name)

def build(out, opt, sanitize):
    out.mkdir(parents=True, exist_ok=True)
    assert ref.invoke(['git','-C',str(ref.SOURCE),'rev-parse','HEAD']).strip() == ref.UPSTREAM
    ref.invoke(['git','-C',str(ref.SOURCE),'diff','--exit-code','HEAD','--'])
    assert ref.invoke(['clang','--version']).splitlines()[:2] == [ref.VERSION, 'Target: '+ref.TARGET]
    text = (ref.SOURCE/'m_menu.c').read_text()
    # Verbatim original includes, globals, prototypes and all menu definitions.
    end = text.index('//\n// M_ReadSaveStrings\n')
    prefix = text[:end]
    units, spans = zip(*(extract(text, name) for name in FUNCTIONS))
    prototypes = re.findall(r'\nvoid\s+(M_\w+)\s*\(([^;]*?)\);', prefix)
    stubs = '\n'.join('void '+name+'('+args+') { abort(); }'
                       for name,args in prototypes if name not in FUNCTIONS)
    generated = prefix+'\nint epi;\nvoid M_VerifyNightmare(int);\nvoid M_DoSave(int);\n'+stubs+'\n'+'\n'.join(units)+'\n#include "host.c"\n'
    (out/'menu.c').write_text(generated)
    (out/'values.h').write_text('#include <limits.h>\n#ifndef MININT\n#define MININT INT_MIN\n#endif\n#ifndef MAXINT\n#define MAXINT INT_MAX\n#endif\n')
    for name in ['v_video.c','m_bbox.c','doomstat.c']:
        shutil.copyfile(ref.SOURCE/name, out/name)
    shutil.copyfile(HERE/'host.c', out/'host.c')
    flags = [('-'+opt if f=='-O2' else f) for f in ref.FLAGS]
    flags += ['-fsigned-char', '-DNORMALUNIX', '-include','stdint.h','-include','stdlib.h',
              '-include','string.h','-include','stdio.h','-ffunction-sections','-fdata-sections',
              '-Wno-incompatible-pointer-types','-Wno-implicit-function-declaration']
    if sanitize: flags += ['-fsanitize=address,undefined','-fno-sanitize=array-bounds','-fno-sanitize-recover=all']
    cmd = ['clang',*flags,'-I'+str(ref.SOURCE),'-I'+str(out),str(out/'menu.c'),
           str(out/'v_video.c'),str(out/'m_bbox.c'),str(out/'doomstat.c'),'-Wl,-dead_strip','-o',str(out/'menu')]
    result = subprocess.run(cmd, capture_output=True, text=True)
    (out/'build.log').write_text(result.stdout+result.stderr)
    if result.returncode: raise RuntimeError(result.stderr)
    return dict(command=cmd, executableSha256=ref.sha((out/'menu').read_bytes()),
                generatedSha256=ref.sha(generated.encode()), extractions=spans,
                definitions=dict(startLine=1,endLine=text[:end].count('\n')+1,sha256=ref.sha(prefix.encode())))

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args=parser.parse_args()
    fixtures=ROOT/'test/fixtures/evm_menu'
    fixtures.mkdir(parents=True, exist_ok=True)
    wad=ROOT/'artifacts/local/freedoom/freedoom1.wad'
    assert ref.sha(wad.read_bytes()) == '7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    records=[]
    canonical=None
    for label,opt,sanitize in [('O0','O0',False),('O2','O2',False),('sanitized','O2',True)]:
        out=ROOT/'artifacts/local/menu-native'/label
        record=build(out,opt,sanitize)
        env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0')
        run=subprocess.run([str(out/'menu'),str(wad),str(out)],capture_output=True,text=True,env=env)
        (out/'run.log').write_text(run.stdout+run.stderr)
        assert run.returncode == 0, run.stderr
        payload={p.name:p.read_bytes() for p in out.glob('*.bin')}
        if canonical is None: canonical=payload
        assert payload == canonical, label
        record.update(profile=label,stderr=run.stderr,outputs={n:ref.sha(b) for n,b in payload.items()})
        records.append(record)
    for name,data in canonical.items():
        path=fixtures/name
        if args.check: assert path.read_bytes() == data, name
        else: path.write_bytes(data)
    # Compact immutable UI pack, exact original WAD bytes; production uses full authenticated WAD.
    wadbytes=wad.read_bytes(); count,offset=struct.unpack_from('<II',wadbytes,4)
    names=set(['TITLEPIC','M_DOOM','M_NGAME','M_OPTION','M_LOADG','M_SAVEG','M_RDTHIS','M_QUITG',
               'M_NEWG','M_SKILL','M_EPISOD','M_EPI1','M_EPI2','M_EPI3','M_EPI4',
               'M_JKILL','M_ROUGH','M_HURT','M_ULTRA','M_NMARE','M_SKULL1','M_SKULL2'])
    names.update(f'STCFN{n:03}' for n in range(33,96))
    blob=bytearray(); directory=bytearray()
    for i in range(count):
        pos,size,name=struct.unpack_from('<II8s',wadbytes,offset+i*16)
        if name.rstrip(b'\0').decode() not in names: continue
        directory += name+struct.pack('<II',len(blob),size)
        blob += wadbytes[pos:pos+size]
    for name,data in [('resources.bin',blob),('directory.bin',directory)]:
        if args.check: assert (fixtures/name).read_bytes()==data
        else: (fixtures/name).write_bytes(data)
    manifest=dict(upstreamCommit=ref.UPSTREAM,compiler=ref.VERSION,target=ref.TARGET,
        sourceHashes={n:ref.sha((ref.SOURCE/n).read_bytes()) for n in ['m_menu.c','m_menu.h','d_main.c','g_game.c','v_video.c']},
        adaptations=['Original menu functions and menu definitions extracted mechanically without body changes.',
            'Unrelated M_* routines abort if invoked; sound is a no-op, deferred startup is observed only.',
            'W_CacheLumpName borrows immutable exact WAD buffers outside any zone; screen buffers calloc via original V_Init.',
            'Apple arm64 LP64, signed-char/wrapv; sanitized variable patch tail uses physical ASan bounds with array-bounds excluded.',
            'Checkpoint setup selects original menu state directly only in native comparison driver; no native pixels enter production.'],
        builds=records,fixtures={n:ref.sha(b) for n,b in canonical.items()},
        harnessHashes={n:ref.sha((HERE/n).read_bytes()) for n in ['reference.py','host.c']})
    (fixtures/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS three original-C profiles:',len(canonical),'checkpoints')

if __name__=='__main__': main()
