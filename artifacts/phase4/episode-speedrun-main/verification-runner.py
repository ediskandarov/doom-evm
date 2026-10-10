import datetime,hashlib,json,pathlib,re,subprocess
root=pathlib.Path('/Users/eduard/sandbox/doom-evm');out=root/'artifacts/phase4/episode-speedrun-main'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda f:json.loads((out/f).read_text())
pre=read('preflight.json');merge=read('merge.json')
sourcehead=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert sourcehead=='a784506fe6c31ac9f85fc909b566f38b5fb1ae7c'
commands=[json.loads(p.read_text()) for p in sorted(out.glob('*.command.json'))]
expected_failures={'speedrun-historical-before':1,'episode-certificate':1,'fresh-launch':1}
for r in commands:assert r['exitCode']==expected_failures.get(r['name'],0),(r['name'],r['exitCode'])
for r in commands:assert sha((out/(r['name']+'.log')).read_bytes())==r['logSha256']
r=read('episode-evm.json')
assert r['pass'] and len(r['frames'])==61 and len(r['inputs'])==1207 and len(r['rollbacks'])==7
assert {(x['from'],x['next']) for x in r['routes']}=={(1,2),(3,9),(9,4),(8,None)}
assert r['nativeGameplay']['tics']==210 and r['nativeGameplay']['frames']==13
assert all(x['allStorageRollback'] for x in r['rollbacks'])
canvas=0
for f in ['episode-evm-browser-intermission.json','episode-evm-browser-finale-controls.json','fresh-launch-final-browser.json']:
 b=read(f);assert b['pass'] and b['stoppedOwnedBrowser'];assert all(f['allCanvasPixelsExact'] for f in b['frames']);canvas+=len(b['frames'])
assert canvas==14
for f in ['speedrun-evm.json','video-evm.json']:
 b=read(f);assert b['pass'] and b['executedTics']==b['verifiedTics']==279 and b['exit']['reached'] and b['ownedRuntimeStopped']
 for file,digest in b['sourceHashes'].items():assert sha((root/file).read_bytes())==digest,file
assert read('video-video-verification.json')['standardEVMFrames']==56
assert read('video-comparison.json')['all56HistoricalFramePixelsExact']
assert read('runtime-cleanup.json')['pass_']
for branch in pre['changedFiles']:
 tip=pre['tips'][branch];assert subprocess.check_output(['git','rev-parse',branch],cwd=root,text=True).strip()==tip
 subprocess.run(['git','merge-base','--is-ancestor',tip,'HEAD'],cwd=root,check=True)
 for p in pre['changedFiles'][branch]:
  if p in ['docs/PHASE4-PLAN.md','tools/reference/speedrun/verify_evidence.py','docs/SPEEDRUN-E1M1.md']:continue
  assert (root/p).read_bytes()==subprocess.check_output(['git','show',tip+':'+p],cwd=root),p
feature='b12eb212fa1f33ba787490327e327611b156f9a0'
c=json.loads(subprocess.check_output(['git','show',feature+':artifacts/phase4/episode-completion/verification.json'],cwd=root))
for p,h in {**c['currentBackendHashes'],**c['currentBrowserHashes'],**c['evidenceHashes'],**c['documentHashes']}.items():
 assert sha(subprocess.check_output(['git','show',feature+':'+p],cwd=root))==h,p
 if p!='docs/PHASE4-PLAN.md':assert sha((root/p).read_bytes())==h,p
oldledger=subprocess.check_output(['git','show',feature+':docs/PHASE4-PLAN.md'],cwd=root).decode()
ledger=(root/'docs/PHASE4-PLAN.md').read_text()
assert oldledger.split('\n\n',1)[1] in ledger
baselineledger=subprocess.check_output(['git','show',pre['baseline']+':docs/PHASE4-PLAN.md'],cwd=root).decode()
assert baselineledger.split('\n\n',1)[1] in ledger
for p,h in pre['protectedLocalHashes'].items():assert sha((root/p).read_bytes())==h
for p in ['AGENTS.md','foundry.toml','execution-budget.json','src/evm/FrameProtocol.sol','src/evm/ResourceTypes.sol','web/protocol.mjs']:
 assert (root/p).read_bytes()==subprocess.check_output(['git','show',pre['baseline']+':'+p],cwd=root),p
assert not subprocess.check_output(['git','-C','original/DOOM','status','--porcelain'],cwd=root,text=True)
commitlists={}
for branch in pre['changedFiles']:
 rows=subprocess.check_output(['git','log','--reverse','--format=%H%x09%s',pre['baseline']+'..'+pre['tips'][branch]],cwd=root,text=True).splitlines()
 commitlists[branch]=[dict(sha=s,message=m) for s,m in (r.split('\t',1) for r in rows)]
for doc in ['docs/PHASE4-PLAN.md','docs/SPEEDRUN-E1M1.md']:
 for target in re.findall(r'\]\(([^)]+)\)',(root/doc).read_text()):
  if '://' in target or target.startswith('#'):continue
  path=target.split('#')[0]
  assert path.endswith('/integration.json') or (root/doc).parent.joinpath(path).exists(),(doc,path)
originalmanifest=json.loads((root/'artifacts/speedrun-e1m1/evidence-manifest.json').read_text())
for file,row in originalmanifest['files'].items():
 data=subprocess.check_output(['git','show','dac56caac8d4eb66f64fd05200829fb17bd892ba:artifacts/speedrun-e1m1/'+file],cwd=root)
 assert len(data)==row['bytes'] and sha(data)==row['sha256'],file
(out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
usage=dict(tokensUsed=185295,goalServiceSeconds=1558,capturedUtc='2026-10-10T17:08:21Z',finalUsageReportedAfterPush=True)
report=dict(kind='episode-completion-and-speedrun-main-integration',pass_=True,scope='focused integration acceptance only; full inherited acceptance deferred',baseline=pre['baseline'],sourceHead=sourcehead,featureTips={r:pre['tips'][r] for r in pre['changedFiles']},sourceCommits=commitlists,merges=merge,compatibilityCommit=sourcehead,conflicts=[],verificationEndpointUtc='2026-10-10T17:08:21Z',measuredStartUtc=pre['startedUtc'],verificationClockSeconds=1567,usageSnapshot=usage,coverage=dict(forgeTests=239,forgeSuites=23,nodeTests=128,nativeGameflowCases=219,nativeFinaleCheckpoints=27,nativeSpeedrunWorlds=280,nativeSpeedrunProfiles=4,productionMaps=9,productionInputTransactions=1207,productionFrames=61,productionNativePlayerTics=210,productionNativeUIFrames=13,storageRootRollbacks=7,productionEdges=[[1,2],[3,9],[9,4],[8,None]],chromeCanvasChecks=14,freshNoRenderReplayWorlds=280,sampledVideoWorlds=280,sampledVideoFrames=56,allPriorSamplePixelsExact=True),interfaces=read('interfaces.json'),preservation=read('preservation.json'),runtimeCleanup=read('runtime-cleanup.json'),retainedFailedAttempts=dict(historicalChecker='Expected integration incompatibility: old certificate compared current source; fixed historical Git-object binding, equality/assertions retained; fresh replay separately passes.',episodeCertificate='Setup ordering: stale ABI/build output before affected production build; original checker passed unchanged after build.',freshLaunch='Owned helper used nonexistent report config path; launcher/cleanup worked; corrected helper path, unchanged Chrome gate passed.'),deferred=['Full-rate DrawBounds at tic52; not retested, no assumption of resolution by Episode memory changes, no speculative fix.','Full inherited Phase0–4 acceptance; honest complete Episode/baron-combat tapes; audio/wipes, other episodes, saves/demos/multiplayer; peak-memory/gas acceptance.','Unchanged transport lifecycle unit that writes browser configuration; actual fresh launcher/Chrome and owned cleanup verified instead.'],noGeneratedMP4OrLocalTemporaryFilesCommitted=True,ledgerSha256=sha(ledger.encode()),historicalEpisodeCertificateSha256=sha((root/'artifacts/phase4/episode-completion/verification.json').read_bytes()),historicalSpeedrunManifestSha256=sha((root/'artifacts/speedrun-e1m1/evidence-manifest.json').read_bytes()),evidenceHashes={str(p.relative_to(root)):sha(p.read_bytes()) for p in sorted(out.iterdir()) if p.is_file() and p.name!='integration.json'})
(out/'integration.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(pass_=True,sourceHead=sourcehead,evidenceFiles=len(report['evidenceHashes']),forge=239,node=128,canvas=14,allNativeEvidenceAndPriorLedgerPreserved=True)))
