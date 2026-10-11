#!/usr/bin/env python3
"""Focused corrected borrowed-UI E1M2 tic84 regression; no historical rerender.

Reuse the freshly built native consumers and unchanged EVM recorder on main.
Preserve the mixed-profile168-byte STTMINUS diagnostic rather than editing it.
"""
import datetime,hashlib,json,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/local/full-options-main/e1m2-native';OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
tape=json.loads((ROOT/'artifacts/local/ultimate-speedruns/E1M2/tape.json').read_text())
report={'scope':__doc__,'startedUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'profiles':{},'pass_':False}
for profile in ['O2','O0','sanitize']:
    previous=None;rows={};binary=ROOT/'artifacts/local/full-options-main/native'/profile/'full-native'
    for tic in [1,20,84]:
        out=OUT/profile/f'tic{tic}';out.mkdir(parents=True)
        commands=out/'commands.txt';commands.write_text(''.join(f"{r['forwardmove']} {r['sidemove']} {r['angleturn']} {r['buttons']} 0\n" for r in tape['commands'][:tic]))
        env={**os.environ,'FULL_CAPTURE_TIC':str(tic),'ASAN_OPTIONS':'detect_leaks=0:halt_on_error=1','UBSAN_OPTIONS':'halt_on_error=1'}
        env.pop('DOOM_ORACLE_ALLOCATION_FILL',None)
        if previous:env['FULL_PREVIOUS_SCREEN']=str(previous)
        run=subprocess.run([str(binary),str(ROOT/'artifacts/local/options/DOOM.WAD'),str(out),str(commands),'2',str(tape['header']['skill']),str(tape['header']['nomonsters'])],capture_output=True,env=env)
        (out/'stdout.log').write_bytes(run.stdout);(out/'stderr.log').write_bytes(run.stderr)
        assert run.returncode==0 and not run.stderr,(profile,tic,run.stderr.decode())
        previous=out/f'gameplay-{tic:06d}.indexed8';palette=out/f'gameplay-{tic:06d}.palette'
        if profile!='O2':
            assert previous.read_bytes()==(OUT/'O2'/f'tic{tic}'/previous.name).read_bytes()
            assert palette.read_bytes()==(OUT/'O2'/f'tic{tic}'/palette.name).read_bytes()
        rows[tic]={'pixelsSha256':sha(previous),'paletteSha256':sha(palette)}
    report['profiles'][profile]={'binarySha256':sha(binary),'frames':rows}
    assert previous.read_bytes()[106*320+290]==8
start=sorted((ROOT/'artifacts/local/full-options-main/native/O2/presentation').glob('*-1-*.indexed8'))[0]
subprocess.run(['python3','tools/reference/full_videos/wipe-frames.py','--start',str(start),'--end',str(OUT/'O2/tic1/gameplay-000001.indexed8'),'--seed','1','--output',str(OUT/'entry-wipe')],cwd=ROOT,check=True)
report.update(pass_=True,entryWipe=json.loads((OUT/'entry-wipe/manifest.json').read_text()),endedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
(OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')
# Derive the bounded runner from the preserved integration runner, with explicit
# replacements and a saved source binding. No implementation or expected pixel changes.
source=(ROOT/'tools/reference/full_options/evm.mjs').read_text()
start=source.index('  assert.equal(matched,317);')
end=source.index('\n }\n const c=await deploy(composed,chunks,8',start)
source=source[:start]+'''  assert.equal(matched,85);assert.deepEqual(bytes(await c.call('snapshot()'),0),states[84]);
  const final=report.frames.at(-1);assert.equal((await readFile(final.localPixels))[106*320+290],8);
  report.checks.push({label:'Corrected borrowed UI E1M2 tic84: all framebuffer/palette bytes native-exact; sampled final pixel8',pass:true,canonicalSnapshots:85,gameplayTics:84,notFullE1M2Replay:true});
'''+source[end:]
start=source.index(' const c=await deploy(composed,chunks,8')
end=source.index(' report.pass=true;',start)
source=source[:start]+source[end:]
for before,after in [('dir=\'artifacts/local/full-options-main/evm\',port=19373','dir=\'artifacts/local/full-options-main/e1m2-evm\',port=19374'),
                     ('artifacts/local/full-options-main/native/','artifacts/local/full-options-main/e1m2-native/'),
                     ('artifacts/local/ultimate-speedruns/E1M1/','artifacts/local/ultimate-speedruns/E1M2/'),
                     ('for(const stress of [false,true])','for(const stress of [false])'),
                     ('chunks,1,stress?','chunks,2,stress?'),('tic<=info.executedTics','tic<=84'),
                     ('[1,20,316].includes(tic)','[1,20,84].includes(tic)'),
                     ("stress?'exit':'exit-default'","'tic84'")]:
    assert before in source,before;source=source.replace(before,after)
# The title is the same authenticated Ultimate TITLEPIC, independently native-generated.
source=source.replace("await nativeCompare(title,stress?'presentation':'presentation-default',rows(stress?'presentation':'presentation-default')[0].file);",'')
source=source.replace("const folder=stress?'presentation':'presentation-default';const uiRows=rows(folder).filter(r=>r.kind!==1);let uiIndex=0;",'')
source='\n'.join(line.rstrip() for line in source.splitlines())+'\n'
target=ROOT/'tools/reference/full_options/e1m2.mjs';target.write_text(source)
report['runnerSha256']=sha(target);(OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS three-profile E1M2 tic84 corrected borrowed UI; bounded EVM runner prepared')
