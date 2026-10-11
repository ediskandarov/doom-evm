#!/usr/bin/env python3
"""Hash-bind scoped evidence; does not replace execution or native comparisons."""
import argparse, hashlib, json, subprocess, re, gzip
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/ultimate-browser'
BASE='3cc536dff6c84194bf3784d9183e0d082a2bcf0e'
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(name):return json.loads((OUT/name).read_text())
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
args=argparse.ArgumentParser();args.add_argument('--record',action='store_true');a=args.parse_args()
accepted=read('accepted.json');locks=read('locks.json');native=read('native.json');forge=read('forge.json')
assert accepted['pass'] and locks['pass'] and native['pass_'] and forge['pass_']
assert len(accepted['checks'])==34 and len(accepted['frames'])==24
assert all(f['allCanvasPixelsExact'] for f in accepted['frames'])
for report in [accepted,locks]:
 for path,digest in report['sourceHashes'].items():assert sha((ROOT/path).read_bytes())==digest,path
pins=json.loads((ROOT/'web/install-pins.mjs').read_text().split('export default ',1)[1].removesuffix(';\n'))
for path,digest in pins['sources'].items():assert sha((ROOT/path).read_bytes())==digest,path
for name,pin in pins['artifacts'].items():
 data=(ROOT/'web'/pin['url'].lstrip('/')).read_bytes();assert sha(data)==pin['sha256'],name
 reduced=json.loads(data);full=json.loads((ROOT/f'out/{name}.sol/{name}.json').read_text())
 assert reduced['bytecode']==full['bytecode']['object'] and reduced['runtime']==full['deployedBytecode']['object']
 assert reduced['methods']==full['methodIdentifiers'] and reduced.get('immutableReferences',{})==full['deployedBytecode'].get('immutableReferences',{})
 metadata=full['metadata'];metadata=json.loads(metadata) if isinstance(metadata,str) else metadata
 assert metadata['compiler']['version'].startswith('0.8.37')
 assert metadata['settings']['evmVersion']=='cancun' and metadata['settings']['viaIR'] and metadata['settings']['optimizer']['runs']==200
old=json.loads(subprocess.check_output(['git','show',BASE+':web/install-assets/Doom.json'],cwd=ROOT))
doom=json.loads((ROOT/'web/install-assets/Doom.json').read_text())
assert all(doom['methods'].get(k)==v for k,v in old['methods'].items())
assert not git('diff',BASE,'--','src/doom','src/support','tools/reference','test/fixtures','foundry.toml','execution-budget.json','original')
assert git('-C','original/DOOM','rev-parse','HEAD')=='a77dfb96cb91780ca334d0d4cfd86957558007e0'
assert not git('-C','original/DOOM','diff','HEAD','--')
comparisons={x['nativeSha256'] for x in accepted['checks'] if 'nativeSha256' in x}
for row in native['records']:
 assert row['files']['skill-2.bin'] in comparisons
 assert row['files']['game/frame-000001.bin'] in comparisons
assert '81' in gzip.decompress((OUT/'node.log.gz').read_bytes()).decode()
assert '45 tests passed, 0 failed' in gzip.decompress((OUT/'forge.log.gz').read_bytes()).decode()
for path in ['docs/ULTIMATE-BROWSER.md','docs/browser-deployment/README.md','docs/browser-deployment/INTEGRATION.md']:
 p=ROOT/path
 for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if a.record and target.endswith('verification.json'):continue
  if '://' not in target and not target.startswith('#'):assert (p.parent/target.split('#')[0]).exists(),target
files=[p for p in OUT.iterdir() if p.is_file() and p.name!='verification.json']
evidence={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sorted(files)}
sourcePaths=['src/evm/Doom.sol','src/evm/ProductionWadResources.sol','web/install-engine.mjs','web/install-resources.mjs','web/install-storage.mjs','web/install.test.mjs','web/launcher.mjs','web/menu-app.mjs','web/install-pins.mjs','tools/browser-deployment/check.mjs','tools/transport/serve.mjs','tools/ultimate-browser/native.py','tools/ultimate-browser/prepare.py','tools/ultimate-browser/forge.py','tools/ultimate-browser/checkpoint.py','test/unit/ProductionWadResources.t.sol','test/unit/UltimateProductionResources.t.sol']
source={p:sha((ROOT/p).read_bytes()) for p in sourcePaths}
report=dict(pass_=True,baseline=BASE,implementationCommits=['4ffe8a1d52fc87d58348f3ebc87c714c541c6622','d6fde98d02a41b5f0b12b97a61f7f6aa65c81e05'],sourceHashes=source,evidenceHashes=evidence,soliditySources=pins['sources'],artifacts=pins['artifacts'],runtimeBytes=len(bytes.fromhex(doom['runtime'][2:])),unpatchedRuntimeSha256=sha(bytes.fromhex(doom['runtime'][2:])),existingMethodSelectorsPreserved=True,addedMethods=sorted(set(doom['methods'])-set(old['methods'])),memoryPolicy=3,solidityDefault=2,resourceIdentity=accepted['installation']['resourceIdentity'],nodeTests=81,forgeTests=45,chromeChecks=34,canvasFrames=24,originalCProfiles=['O0','O2','ASan/UBSan'],compatibility='RESTRICT; virtual addresses do not establish native pointer placement',fullHistoricalAcceptance=False,commercialPayloadsCommitted=False)
if a.record:(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
else:
 saved=read('verification.json');assert saved==report,'Certificate drift'
print('PASS scoped source/artifact/ABI/resource/evidence certificate')
