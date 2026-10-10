#!/usr/bin/env python3
"""Fresh compiler, macro and original-struct layout inventory; no fixture writes."""
import argparse, ast, hashlib, json, pathlib, re, shutil, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[3];HERE=pathlib.Path(__file__).resolve().parent;SRC=ROOT/'original/DOOM/linuxdoom-1.10';OUT=ROOT/'artifacts/phase4/native-memory-audit'
sha=lambda b:hashlib.sha256(b).hexdigest()
def run(cmd):
    r=subprocess.run(cmd,capture_output=True);assert r.returncode==0,r.stderr.decode();return r.stdout

def main():
    global OUT
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=pathlib.Path,default=OUT);args=ap.parse_args();OUT=args.output.resolve()
    OUT.mkdir(parents=True,exist_ok=True);compiler=shutil.which('clang');source_layout=ROOT/'tools/reference/phase3_zone_lifecycle/layout.py'
    tree=ast.parse(source_layout.read_text());fields=next(ast.literal_eval(s.value) for s in tree.body if isinstance(s,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='fields' for t in s.targets))
    private=[]
    for file,name in [('z_zone.c','memzone_t'),('r_data.c','texpatch_t'),('r_data.c','texture_t')]:
        text=(SRC/file).read_text();end=re.search(r'}\s*'+name+r'\s*;',text).end();start=text.rfind('typedef struct',0,end);private.append(text[start:end])
    code='#include <stdio.h>\n#include <stddef.h>\n#include "r_local.h"\n#include "p_local.h"\n#include "z_zone.h"\n'+'\n'.join(private)+'\nint main(void){\n'
    for typ,fs in fields.items():
        code+=f'printf("{typ} SIZEOF %zu\\n{typ} ALIGNOF %zu\\n",sizeof({typ}),_Alignof({typ}));\n'
        for field in fs.split():code+=f'printf("{typ} {field} %zu\\n",offsetof({typ},{field}));\n'
    code+='return 0;}\n'
    records=[];macros={}
    with tempfile.TemporaryDirectory(prefix='doom-memory-layout-') as td:
        temp=pathlib.Path(td);(temp/'layout.c').write_text(code)
        cmd=[compiler,'-std=c11','-I'+str(SRC),str(temp/'layout.c'),'-o',str(temp/'layout')];run(cmd);raw=run([str(temp/'layout')]);measured={}
        for line in raw.decode().splitlines():
            typ,field,value=line.split();entry=measured.setdefault(typ,{'offsets':{}})
            if field in ['SIZEOF','ALIGNOF']:entry[{'SIZEOF':'size','ALIGNOF':'alignment'}[field]]=int(value)
            else:entry['offsets'][field]=int(value)
        fixture=json.loads((ROOT/'test/fixtures/phase3_zone_lifecycle/layout.json').read_text())
        for typ,entry in measured.items():assert entry==fixture['layout'][typ],typ
        records.append(dict(kind='fresh native all-type layout',command=cmd,sourceSha256=sha(code.encode()),executableSha256=sha((temp/'layout').read_bytes()),matchedTypes=len(measured),measured=measured))
        # Freestanding compile-only comparison. This is modern Clang under an
        # explicitly selected ABI, not execution of a historic Linux executable.
        header=(SRC/'z_zone.h').read_text();start=header.index('typedef struct memblock_s');end=header.index('} memblock_t;',start)+len('} memblock_t;')
        typedefs=header[start:end]+'\n'+private[0]
        consts=['sizeof(int)','sizeof(long)','sizeof(void*)','sizeof(memblock_t)','_Alignof(memblock_t)','sizeof(memzone_t)']+[f'__builtin_offsetof(memblock_t,{f})' for f in fields['memblock_t'].split()]
        comparison=typedefs+'\nconst unsigned audit_sizes[]={'+','.join(consts)+'};\n';(temp/'abi.c').write_text(comparison)
        for target in ['arm64-apple-darwin24.6.0','i386-unknown-linux-gnu','x86_64-unknown-linux-gnu']:
            command=[compiler,'-target',target,'-ffreestanding','-std=c11','-S','-emit-llvm',str(temp/'abi.c'),'-o','-'];ir=run(command).decode();initializer=re.search(r'@audit_sizes = .*?constant \[12 x i32\] \[([^\]]+)\]',ir);assert initializer,ir
            vals=[int(x) for x in re.findall(r'i32 (\d+)',initializer.group(1))]
            records.append(dict(kind='compile-only ABI comparison',target=target,command=command,sourceSha256=sha(comparison.encode()),irSha256=sha(ir.encode()),labels=consts,values=vals))
        for name,flags in [('base',['-std=c99']),('gameplay',['-std=c99','-fsigned-char','-DNORMALUNIX'])]:
            command=[compiler,*flags,'-dM','-E','-I'+str(SRC),'-include','doomdef.h','-x','c','/dev/null'];raw=run(command);(OUT/(name+'-macros.txt')).write_bytes(raw)
            wanted=['__APPLE__','__MACH__','__aarch64__','__arm64__','__LP64__','__SIZEOF_INT__','__SIZEOF_LONG__','__SIZEOF_POINTER__','__BYTE_ORDER__','__ORDER_LITTLE_ENDIAN__','__CHAR_UNSIGNED__','__STDC_VERSION__','RANGECHECK','NORMALUNIX','LINUX','USEASM','__BIG_ENDIAN__']
            definitions=dict(re.findall(r'^#define (\S+)(?: (.*))?$',raw.decode(),re.M))
            macros[name]=dict(command=command,sha256=sha(raw),selected={k:definitions.get(k) for k in wanted})
    paths=[HERE/'inventory.py',HERE/'check.py',ROOT/'tools/reference/reference.py',ROOT/'tools/reference/renderer/build.py',ROOT/'tools/reference/renderer/host.c',ROOT/'tools/reference/gameplay/build.py',ROOT/'tools/reference/gameplay/host.c',ROOT/'tools/reference/phase2_data/reference.py',ROOT/'tools/reference/phase2_data/compat.h',ROOT/'tools/reference/phase2_data/driver.c',ROOT/'tools/reference/phase3_zone_allocator/reference.py',ROOT/'tools/reference/phase3_zone_allocator/host.c',ROOT/'tools/reference/phase3_zone_backing/reference.py',source_layout,ROOT/'tools/zone/generate-layout.py',ROOT/'tools/reference/phase3_zone_lifecycle/reference.py',ROOT/'tools/reference/ui/reference.py',ROOT/'tools/reference/input-runtime/reference.py',ROOT/'tools/reference/episode_startup/reference.py',ROOT/'tools/reference/drawbounds_blood/reference.py',ROOT/'tools/reference/drawbounds_blood/host.c',ROOT/'tools/reference/episode_completion/pointer.py',ROOT/'src/doom/z_zone.sol',ROOT/'src/doom/z_zone_types.sol',ROOT/'src/doom/z_zone_backing.sol',ROOT/'src/doom/native_zone_layout.sol',ROOT/'src/doom/r_data.sol',ROOT/'src/doom/w_zone_cache.sol',ROOT/'src/evm/Doom.sol',ROOT/'src/evm/DoomGame.sol',ROOT/'src/evm/EpisodeStartup.sol',ROOT/'test/fixtures/phase3_zone_lifecycle/layout.json',ROOT/'test/fixtures/phase2_data/manifest.json',ROOT/'test/fixtures/phase2_data/resources.bin',ROOT/'artifacts/phase4/episode-completion/pointer-native.json',ROOT/'artifacts/phase4/episode-completion/composite-native-binding.json']
    assert all(p.exists() for p in paths), [str(p) for p in paths if not p.exists()]
    result=dict(compiler=compiler,version=run([compiler,'--version']).decode(),records=records,macros=macros,sourceHashes={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in paths},scope='Fresh all-type native layout plus compile-only selected ABI comparison. No historic Linux execution or historical GCC identity claimed.')
    (OUT/'inventory.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'matchedNativeTypes':records[0]['matchedTypes'],'abiComparisons':{x['target']:x['values'] for x in records[1:]}}))
if __name__=='__main__':main()
