#!/usr/bin/env python3
"""Bind the finite functional handoff without relabeling failed historical runs."""
import hashlib, json, pathlib, re, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/phase4/episode-completion'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda name:json.loads((OUT/(name+'.json')).read_text())
routing=load('functional'); completion=load('completion-final')
fresh=load('browser-fresh'); wi=load('functional-browser-intermission')
browser=load('completion-final-browser-finale-controls')
assert not routing['pass'] and '0 !== 2' in routing['error']
assert routing['nativeGameplay']['tics']==210 and routing['nativeGameplay']['frames']==13
assert {(r['from'],r['next']) for r in routing['routes']}=={(1,2),(3,9),(9,4)}
maps={o['params'][0] for o in routing['operations'] if o['operation']=='newEpisodeGame(int32,int32,uint32)'}
assert maps>=set(range(1,10))
assert len(routing['rollbacks'])==7 and all(r['allStorageRollback'] for r in routing['rollbacks'])
assert completion['pass'] and completion['routes'][0]['from']==8 and completion['routes'][0]['next'] is None
assert all(completion['legacy'][k] for k in ['staticNativeExact','worldOnlyNativeExact','rawInput'])
for label in ['Legacy UI','E1M8 original finale']:
    assert any(f['label']==label and f['nativeExact'] for f in completion['frames'])
assert fresh['pass'] and wi['pass'] and browser['pass']
assert wi['frames'][0]['state']['state']==1 and browser['frames'][0]['state']['state']==2
assert all(f['allCanvasPixelsExact'] for j in [fresh,wi,browser] for f in j['frames'])
assert load('focused-final')['counts']==[175,0,0,175]
assert load('input-final')['counts']==[73,0,0,73]
assert 'tests 58' in (OUT/'node-final.log').read_text() and 'fail 0' in (OUT/'node-final.log').read_text()
backend={p:h for p,h in completion['sourceHashes'].items() if p.startswith('src/') or p in ['foundry.toml','execution-budget.json']}
for p,h in backend.items(): assert sha(ROOT/p)==h,p
for p,h in fresh['sourceHashes'].items(): assert sha(ROOT/p)==h,p
assert sha(OUT/'browser-check-before-fresh.mjs')==completion['sourceHashes']['tools/transport/episode-browser-check.mjs']
base='0141708e9772c40a4b43f6fc631e0364fa0eb1a4'
protected=['foundry.toml','execution-budget.json','src/evm/FrameProtocol.sol','src/evm/ResourceTypes.sol','web/protocol.mjs']
for p in protected: assert (ROOT/p).read_bytes()==subprocess.check_output(['git','show',base+':'+p])
changed=subprocess.check_output(['git','diff','--name-only',base,'--','test/fixtures','original','schemas'],text=True).splitlines()
assert all(p.startswith('test/fixtures/phase4_finale/') for p in changed),changed
documents=['README.md','PORTING.md','docs/PHASE4-EPISODE-COMPLETION.md','docs/PHASE4-PLAN.md']
for file in documents:
    for target in re.findall(r'\]\(([^)]+)\)',(ROOT/file).read_text()):
        if '://' in target or target.startswith('#'): continue
        path=target.split('#')[0]
        if path and not path.endswith('verification.json'): assert ((ROOT/file).parent/path).exists(),(file,path)
manifest=json.loads((ROOT/'test/fixtures/phase4_finale/manifest.json').read_text())
for name,h in manifest['files'].items(): assert sha(ROOT/'test/fixtures/phase4_finale'/name)==h,name
artifact=json.loads((ROOT/'out/Doom.sol/Doom.json').read_text())
report=dict(kind='episode-one-functional-feature-certificate',pass_=True,baseline=base,
    implementationTip='4be57da6b67668b8d16260e009249279fb75a418',branch='feat/phase4-episode-completion',mainIntegrated=False,pushed=False,
    measuredStartUtc='2026-10-10T14:51:41Z',verificationEndUtc='2026-10-10T16:06:15Z',clockIntervalSeconds=4474,
    usageSnapshot=load('usage-snapshot'),compiler=completion['compiler'],executionBudget=completion['executionBudget'],resourceIdentity=completion['resourceIdentity'],
    currentBackendHashes=backend,currentBrowserHashes=fresh['sourceHashes'],
    abiSha256=hashlib.sha256(json.dumps(artifact['abi'],separators=(',',':')).encode()).hexdigest(),
    runtimeBytes=928442,runtimeSha256='219e2732fabf70b9a22a7dcc3aaa538ec8fbb2d7786a68b0a9d148a375b1ed1d',
    coverage=dict(uniqueFocusedForgeTests=239,nodeTests=58,nativeGameflowCases=219,nativeFinaleCheckpoints=27,nativeCompositeRecords=963,nativeTailCases=80,
        originalE1M1Tics=210,playerFieldsPerTic=14,nativeUIFrames=13,productionMapInitializations=9,productionEdges=[[1,2],[3,9],[9,4],[8,None]],
        routingStorageRootRollbacks=7,completionRollbacks=3,chromeFrames=14),
    scopeChecks=dict(originalCUnchanged=True,inheritedFixturesUnchanged=True,compilerBudgetSchemasProtocolsUnchanged=True,ownedRuntimesStopped=True),
    reportSelection=dict(routing='functional.json: required routing/native/map subcases pass; overall first E1M8 approach remains failed',
        completion='completion-final.json: corrected E1M8 and legacy checks pass',
        browserHarness='Earlier captured browser version retained byte-exact as browser-check-before-fresh.mjs; fresh proof binds the later --fresh entry option.'),
    limitations=['Episode-only current-header pointer bytes6/7 require an explicit native address domain below2^48 and integrator review; provenance3 is conditional, not whole-process memory equivalence.',
        'Current source-written composites use the original generator without native cache effects; freed/mutable bodies, retired headers and lower pointers remain unknown.',
        'Exit proofs use declared original God/noclip inputs and authentic triggers, not storage injections or honest complete episode tapes.',
        'Audio/wipes, other episodes, demos/saves/multiplayer, gas optimization and complete historical release acceptance are excluded.',
        'No peak-memory,35Hz or mainnet-size claim.'],
    evidenceHashes={str(p.relative_to(ROOT)):sha(p) for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='verification.json'},
    documentHashes={p:sha(ROOT/p) for p in documents},runnerSha256=sha(pathlib.Path(__file__)))
path=OUT/'verification.json'; data=(json.dumps(report,indent=2)+'\n').encode()
if '--check' in __import__('sys').argv: assert path.read_bytes()==data,'certificate drift'
else: path.write_bytes(data)
print(json.dumps(dict(pass_=True,coreSourceFiles=len(backend),uniqueForgeTests=239,nodeTests=58,evidenceFiles=len(report['evidenceHashes']))))
