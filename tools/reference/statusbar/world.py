#!/usr/bin/env python3
"""Focused native 320x168 world + status32 composition; accepted renderer builder unchanged."""
import argparse,hashlib,importlib.util,json,os,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'test/fixtures/phase4_statusbar_world'
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    spec=importlib.util.spec_from_file_location('renderer_builder',HERE.parent/'renderer/build.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    wad=ROOT/'artifacts/local/freedoom/freedoom1.wad'
    assert sha(wad.read_bytes())=='7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d'
    host=(builder.HERE/'host.c').read_text();assert host.count('screenblocks=11')==1
    adapted=host.replace('screenblocks=11','screenblocks=10')
    results=[];profiles=[]
    with tempfile.TemporaryDirectory(prefix='doom-status-world-') as td:
        tmp=Path(td);harness=tmp/'harness';harness.mkdir()
        (harness/'host.c').write_text(adapted);shutil.copyfile(builder.HERE/'trace.h',harness/'trace.h');builder.HERE=harness
        for name,opt,san in [('O0','O0',False),('O2','O2',False),('sanitized','O2',True)]:
            binary=builder.build(tmp/name,opt,san);dest=tmp/(name+'-output');dest.mkdir()
            run=subprocess.run([str(binary),str(wad),str(dest),'0','full'],capture_output=True,env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0','UBSAN_OPTIONS':'halt_on_error=1'})
            assert run.returncode==0,run.stderr.decode();assert not run.stderr,run.stderr.decode()
            pixels=(dest/'pixels.bin').read_bytes();assert len(pixels)==64000;assert pixels[53760:]==bytes(10240)
            results.append(pixels);profiles.append({'name':name,'sha256':sha(pixels)})
        assert results[0]==results[1]==results[2]
        status=(ROOT/'test/fixtures/phase4_statusbar/inventory-0.frame').read_bytes()
        combined=results[0][:53760]+status[53760:]
        metadata={'profiles':profiles,'worldView':[320,168],'frame':[320,200],'barSource':'phase4_statusbar/inventory-0.frame','barSha256':sha(status[53760:]),'frameSha256':sha(combined),'rendererBuilderSha256':sha((HERE.parent/'renderer/build.py').read_bytes()),'originalHostSha256':sha(host.encode()),'adaptedHostSha256':sha(adapted.encode()),'adaptation':'Host screenblocks=11 -> screenblocks=10; original R_ExecuteSetViewSize chooses 320x168. Original native status first-refresh bottom32 copied into complete native world frame. No gameplay ticks/world edits.'}
        files={'world.bin':results[0],'frame.bin':combined,'manifest.json':(json.dumps(metadata,indent=2)+'\n').encode()}
        OUT.mkdir(exist_ok=True)
        for name,data in files.items():
            if args.check:assert (OUT/name).read_bytes()==data,name
            else:(OUT/name).write_bytes(data)
    print('320x168 native world + original 320x32 status: O0/O2/sanitizers exact')
if __name__=='__main__':main()
