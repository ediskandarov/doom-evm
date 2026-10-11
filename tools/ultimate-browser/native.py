#!/usr/bin/env python3
"""Focused original-C menu and first gameplay/Status Bar comparison only."""
import importlib.util, json, os, subprocess, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
menu=load('ultimate_menu','tools/reference/menu/reference.py')
ui=load('ultimate_ui','tools/reference/ui/reference.py')
wad=ROOT/'artifacts/local/ultimate-doom/DOOM.WAD'
assert hashlib.md5(wad.read_bytes()).hexdigest()=='c4fe9fd920207691a9f493668e0a2083'
out=ROOT/'artifacts/local/ultimate-browser/native';out.mkdir(parents=True,exist_ok=True)
records=[];baseline=None
for label,opt,san in [('O0','O0',False),('O2','O2',False),('sanitized','O2',True)]:
 dest=out/label;dest.mkdir(exist_ok=True)
 build=menu.build(dest/'menu-build',opt,san)
 env={**os.environ,'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1','DOOM_ORACLE_ALLOCATION_FILL':'0'}
 p=subprocess.run([str(dest/'menu-build/menu'),str(wad),str(dest)],capture_output=True,env=env)
 assert p.returncode==0 and not p.stderr,p.stderr
 binary=ui.build_ui(dest/'ui-build',opt,san)
 (dest/'commands.txt').write_text('0 0 0 0 1 0\n')
 game=dest/'game';game.mkdir(exist_ok=True)
 p=subprocess.run([str(binary),str(wad),str(game),str(dest/'commands.txt'),'ordinary'],capture_output=True,env=env)
 assert p.returncode==0 and not p.stderr,p.stderr
 files={str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [*dest.glob('*.bin'),*game.glob('frame*.bin'),*game.glob('palette*.bin')]}
 if baseline is None:baseline=files
 else:assert baseline==files,label
 records.append(dict(profile=label,menuBuild=build,files=files,uiExecutableSha256=hashlib.sha256(binary.read_bytes()).hexdigest()))
report=dict(pass_=True,kind='focused-original-C-retail-menu-first-frame-status-bar',wadSha256=hashlib.sha256(wad.read_bytes()).hexdigest(),upstreamCommit=menu.ref.UPSTREAM,records=records)
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS Ultimate original-C menu/first gameplay+Status Bar: O0/O2/ASan-UBSan exact')
