#!/usr/bin/env python3
"""Run focused Save/Load and affected dependency checks without historical acceptance."""
import datetime, hashlib, json, os, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
out=ROOT/'artifacts/local/save-load';out.mkdir(parents=True,exist_ok=True)
tests=['test/unit/p_saveg.t.sol','test/unit/SaveSlots.t.sol','test/unit/SaveMenu.t.sol',
       'test/unit/m_menu.t.sol','test/unit/OptionsMenu.t.sol','test/doom2/Menu.t.sol']
wrapper=out/'forge-tests/Imports.t.sol';wrapper.parent.mkdir(exist_ok=True)
wrapper.write_text('// SPDX-License-Identifier: GPL-2.0-only\npragma solidity 0.8.37;\n'+
                   ''.join(f'import "../../../../{p}";\n' for p in tests))
(out/'empty-src').mkdir(exist_ok=True)
env=dict(os.environ,FOUNDRY_SRC=str(out/'empty-src'),FOUNDRY_TEST=str(wrapper.parent),
         FOUNDRY_OUT=str(out/'forge-out'),FOUNDRY_CACHE_PATH=str(out/'forge-cache'))
utc=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
report={'kind':__doc__,'pass':False,'startedUtc':utc(),'commands':[], 'sourceHashes':{}}
commands=[('.toolchain/bin/forge test --json'.split(),env,'forge-final'),
          (['node','--test','--test-reporter=tap','tools/reference/save_load/keybindings.test.mjs',
            'web/menu-input.test.mjs','web/input.test.mjs','web/input-loop.test.mjs',
            'web/browser-profiles.test.mjs','tools/reference/gameplay/production-memory.test.mjs',
            'tools/reference/phase2_data/instrument.test.mjs','web/install.test.mjs','web/doom2-profile.test.mjs'],os.environ,'node-final'),
          (['python3','tools/reference/save_load/schema.py','--check'],os.environ,'schema-final')]
try:
    for command,environment,name in commands:
        start=utc();r=subprocess.run(command,cwd=ROOT,env=environment,text=True,capture_output=True)
        stdout=out/(name+('.json' if name=='forge-final' else '.log'));stderr=out/(name+'.stderr.log')
        stdout.write_text(r.stdout);stderr.write_text(r.stderr)
        row={'argv':command,'exitCode':r.returncode,'startedUtc':start,'endedUtc':utc(),
             'stdoutSha256':sha(stdout),'stderrSha256':sha(stderr)}
        if name=='forge-final' and r.returncode==0:
            results=json.loads(r.stdout);cases=[v for x in results.values() for v in x['test_results'].values()]
            assert all(v['status']=='Success' for v in cases);row['passedTests']=len(cases)
        if name=='node-final' and r.returncode==0:
            assert '# fail 0' in r.stdout;row['passedTests']=int(next(s.split()[-1] for s in r.stdout.splitlines() if s.startswith('# pass ')))
        report['commands'].append(row);print(name,r.returncode,row.get('passedTests',''),flush=True)
        if r.returncode:raise RuntimeError(name+' failed; see retained logs')
    for p in tests+['foundry.toml','tools/reference/save_load/focused.py','tools/reference/save_load/keybindings.test.mjs']:
        report['sourceHashes'][p]=sha(ROOT/p)
    report['pass']=True
finally:
    report['endedUtc']=utc();published=ROOT/'artifacts/save-load/focused.json'
    published.parent.mkdir(exist_ok=True);published.write_text(json.dumps(report,indent=2)+'\n')
