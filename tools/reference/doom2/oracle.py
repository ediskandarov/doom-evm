#!/usr/bin/env python3
"""Original C replay with declared commercial host globals and MAPxx selection.
Original gameplay, rendering, allocator and G_InitNew bodies remain unchanged.
"""
import sys, subprocess, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/reference/speedrun'))
import replay
from replay import sha,save,renderer,PUNITS

def build_replay(out,opt,sanitize):
    binary=replay.build_replay(out,opt,sanitize)
    p=out/'original-host.c';s=p.read_text()
    replacements=[('gamemode=retail;gamemission=doom;', 'gamemode=commercial;gamemission=doom2;'),
        ('episode_map>9','episode_map>32'),
        ('"E1M%d",episode_map','"MAP%02d",episode_map')]
    for before,after in replacements:
        assert s.count(before)==1,(before,s.count(before));s=s.replace(before,after)
    p.write_text(s)
    manifest=json.loads((out/'speedrun-build-manifest.json').read_text())
    flags=[f.replace('<BUILD>',str(out)).replace('<HARNESS>',str(ROOT/'tools/reference')) for f in manifest['flags']]
    cmd=['clang',*flags,'-I'+str(out),*[str(out/n) for n in renderer.UNITS+PUNITS],str(out/'game_functions.c'),str(out/'episode-host.c'),'-Wl,-dead_strip','-o',str(binary)]
    result=subprocess.run(cmd,capture_output=True);(out/'doom2-build.log').write_bytes(result.stdout+result.stderr)
    assert result.returncode==0,result.stderr.decode()
    manifest.update(commercialHostAdaptations=replacements,commercialHostSHA256=sha(s.encode()),commercialBuildCommand=cmd,executableSHA256=sha(binary.read_bytes()))
    save(out/'speedrun-build-manifest.json',manifest)
    return binary
