#!/usr/bin/env python3
import json, pathlib, platform, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[1]
lock=json.loads((ROOT/'toolchain.lock.json').read_text())
versions={}
for name in ('forge','cast','anvil','solc'):
    output=subprocess.check_output([str(ROOT/'.toolchain/bin'/name),'--version'],text=True).strip()
    expected=lock['solc'] if name=='solc' else lock['foundry']
    commit=lock['solc_commit'] if name=='solc' else lock['foundry_commit']
    if expected not in output or commit not in output: raise SystemExit(f'{name} does not match toolchain.lock.json: {output}')
    versions[name]=output
node=subprocess.check_output(['node','--version'],text=True).strip()
if node!='v'+lock['node']: raise SystemExit(f'Use Node {lock["node"]}; found {node}')
versions['node']=node
versions['python']=platform.python_version()
versions['host']=platform.platform()
upstream=subprocess.check_output(['git','-C',str(ROOT/'original/DOOM'),'rev-parse','HEAD'],text=True).strip()
if upstream!='a77dfb96cb91780ca334d0d4cfd86957558007e0': raise SystemExit('Wrong upstream SHA')
versions['upstream_commit']=upstream
config=json.loads(subprocess.check_output([str(ROOT/'.toolchain/bin/forge'),'config','--json'],cwd=ROOT,text=True))
assert config['via_ir'] is True and config['optimizer'] is True and config['optimizer_runs']==200
assert config['evm_version']=='cancun'
versions['compiler_settings']={key:config[key] for key in ('solc','via_ir','optimizer','optimizer_runs','evm_version')}
print(json.dumps(versions,indent=2))
