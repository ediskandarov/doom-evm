#!/usr/bin/env python3
"""Refresh separate compatibility source bindings; never rewrite Phase3 acceptance.

Proof/source integrity only. This tool does not run or infer correctness tests.
"""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(data):return hashlib.sha256(data).hexdigest()
def digest(path):return sha((ROOT/path).read_bytes())
def git_bytes(revision,path):return subprocess.check_output(['git','show',revision+':'+path],cwd=ROOT)
def scrub(text):return re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"',lambda m:re.sub(r'[^\n]',' ',m[0]),text,flags=re.S)
def spans(path):
 raw=(ROOT/path).read_text();clean=scrub(raw);out={}
 for m in re.finditer(r'\bfunction\s+(\w+)\s*\([^;{}]*\)[^;{}]*\{',clean):
  at=m.end();depth=1
  while depth:
   depth+=(clean[at]=='{')-(clean[at]=='}');at+=1
  name=m[1];key=name if name not in out else name+'#'+str(sum(k.split('#')[0]==name for k in out)+1)
  out[key]={'path':path,'startLine':raw.count('\n',0,m.start())+1,'endLine':raw.count('\n',0,at)+1,'bodySha256':sha(raw[m.start():at].encode()),'declaration':re.sub(r'\s+','',clean[m.start():m.end()-1])}
 return out

def build(checkpoint_path):
 checkpoint=json.loads((ROOT/checkpoint_path).read_text());assert checkpoint['kind']=='phase3-post-acceptance-compatibility';assert checkpoint['pass'] is True
 historic=checkpoint['historicalAcceptance'];path=historic['path'];assert digest(path)==historic['sha256'],'historical certificate changed'
 cert=json.loads((ROOT/path).read_text());revision=historic['frozenSourceRevision']
 assert cert['M2']==cert['M3']=='passed'
 for source,h in cert['sourceHashes'].items():assert sha(git_bytes(revision,source))==h,('frozen source',source)
 for proof in cert['proofs'].values():assert digest(proof['path'])==proof['sha256'],('historical proof',proof['path'])
 for source,h in checkpoint['sourceHashes'].items():assert digest(source)==h,('current source',source)
 assert set(checkpoint['sourceHashes'])=={str(p.relative_to(ROOT)) for p in (ROOT/'src').rglob('*.sol')},'incomplete source bindings'
 for proof in checkpoint['proofs'].values():assert digest(proof['path'])==proof['sha256'],('compatibility proof',proof['path'])
 required={'phase0','phase1','phase2','phase3Regressions','foundry','capturedInitialized','capturedStrict','wholeKernel','storageLayout','nativeIndeterminate','publicProduction','browser'}
 assert required<=set(checkpoint['regressionGates']),'missing regression category'
 assert all(v['pass'] for v in checkpoint['regressionGates'].values()),'incomplete regressions'
 matrix_path='artifacts/phase3/feature-matrix.json';matrix=json.loads((ROOT/matrix_path).read_text());assert digest(matrix_path)==checkpoint['historicalFeatureMatrixSha256']
 current={path:spans(path) for path in checkpoint['sourceHashes']};bindings=[]
 for row in matrix['functions']:
  port=row.get('port');target=None
  if port:
   old=git_bytes(revision,port['path']).decode();fragment='\n'.join(old.splitlines()[port['startLine']-1:port['endLine']]);match=re.search(r'\bfunction\s+(\w+)\s*\([^;{}]*\)[^;{}]*\{',scrub(fragment));assert match,(row['function'],port)
   declaration=re.sub(r'\s+','',match[0][:-1]);matches=[v for v in current[port['path']].values() if v['declaration']==declaration];assert len(matches)==1,(row['function'],'ambiguous signature')
   target=matches[0]
  bindings.append({'module':row['module'],'function':row['function'],'originalSource':row['source'],'historicalPort':port,'currentPort':target,'changedPortBody':bool(port and port['bodySha256']!=target['bodySha256']),'verificationScope':'Historical module/integration evidence remains at its recorded revision; current compatibility proofs are separate, not per-function branch certification.'})
 changed=[p for p,h in checkpoint['sourceHashes'].items() if p in cert['sourceHashes'] and h!=cert['sourceHashes'][p]]
 return {'schemaVersion':1,'kind':'post-acceptance-compatibility-source-audit','pass':True,'checkpoint':{'path':checkpoint_path,'sha256':digest(checkpoint_path)},'historicalAcceptance':historic,'historicalM2M3':'Passed at frozen revision only; not relabeled current','currentVerificationScope':checkpoint['scope'],'sourceBindings':checkpoint['sourceHashes'],'changedEngineSources':sorted(changed),'functionBindings':bindings,'helperDefinitions':{p:current[p] for p in changed},'provenancePolicy':{'originalSourceWritten':1,'deterministicallyInitialized':2,'unknownOrInvalid':0,'strictDiagnostic':True,'nativePixelComparison':'Source-defined draws retain original comparisons; initial-byte-dependent draws use explicitly identified zero-initialized native profile only.'},'limitations':checkpoint['limitations']}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--checkpoint',default='artifacts/phase3/drawbounds-compatibility.json');parser.add_argument('--output',default='artifacts/phase3/drawbounds-source-audit.json');parser.add_argument('--check',action='store_true');args=parser.parse_args()
 output=Path(args.output);certificate=json.loads((ROOT/'artifacts/phase3/acceptance.json').read_text())
 protected={'artifacts/phase3/acceptance.json','artifacts/phase3/feature-matrix.json','docs/PHASE3-FEATURE-MATRIX.md'}|{p['path'] for p in certificate['proofs'].values()}
 assert (ROOT/output).resolve() not in {(ROOT/p).resolve() for p in protected},'protected historical output'
 payload=build(args.checkpoint);content=json.dumps(payload,indent=2)+'\n';target=ROOT/output
 if args.check:assert target.read_text()==content,'stale compatibility audit'
 else:target.write_text(content)
 print(json.dumps({'pass':True,'scope':payload['currentVerificationScope'],'functionBindings':len(payload['functionBindings']),'changedEngineSources':payload['changedEngineSources']}))
if __name__=='__main__':main()
