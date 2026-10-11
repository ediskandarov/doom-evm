#!/usr/bin/env python3
"""Inventory retained attempts/log failures without executing or changing EVM state."""
import datetime,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];LOCAL=ROOT/'artifacts/local/full-videos'
sha=lambda b:hashlib.sha256(b).hexdigest()
attempts=[];logs=[]
for p in sorted(LOCAL.glob('E1M*/*/recording.json')):
 r=json.loads(p.read_text());tx=r.get('transactions',[]);failed=[t for t in tx if t['status']!='0x1']
 lineage=r.get('checkpointLineage')
 if lineage:lineage={k:v for k,v in lineage.items() if k!='parentIdentity'}
 attempts.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p.read_bytes()),map=r.get('identity',{}).get('map'),complete=r.get('pass'),error=r.get('error'),frames=len(r.get('frames',[])),gameplayTics=r.get('gameplayTics'),recordedTransactions=len(tx),failedMinedTransactions=len(failed),failedReceipts=failed,resumeSessions=r.get('resumeSessions',[]),checkpointLineage=lineage,gasIncludingInheritedReceipts=sum(t['gas'] for t in tx)))
for p in sorted(set(LOCAL.glob('E1M*/*/pipeline.log'))|set(LOCAL.glob('E1M*/pilot-*.log'))):
 lines=p.read_text(errors='replace').splitlines();errors=[]
 for n,line in enumerate(lines,1):
  if re.match(r'^(Error:|AssertionError(?:\b| \[))',line):
   category=('requested recoverable stop' if 'Recoverable requested stop' in line else 'occupied-port guard' if 'Occupied port' in line else 'mined EVM frame transaction reverted' if 'Frame transaction reverted' in line else 'verification assertion' if line.startswith('AssertionError') else 'execution error')
   errors.append(dict(line=n,text=line,category=category))
 logs.append(dict(path=str(p.relative_to(ROOT)),sha256=sha(p.read_bytes()),observedErrors=errors))
report=dict(measuredUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Retained local recording manifests and attempt logs only. Failed UI/native gates, requested checkpoint stops and occupied-port refusal are not failed gameplay transactions. Diagnostic and rollback gas are excluded from final recording totals.',automaticTransactionResubmission=0,automaticTransactionResubmissionBasis='Source audit: recorder send()/rpc() submits once; receipt polling does not resubmit transactions. Manual checkpoint resume counts are separately recorded.',attempts=attempts,logs=logs,aggregateAttemptGas=None,aggregateAttemptGasUnavailableReason='Attempts/checkpoint policy forks share inherited receipts; summing attempt gas would double-count. Costs per retained attempt are shown with explicit lineage. Unreceipted RPC failures have no measured gas.')
(ROOT/'artifacts/full-videos/attempt-inventory.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(attempts=len(attempts),logs=len(logs),observedLogErrors=sum(len(x['observedErrors']) for x in logs))))
