#!/usr/bin/env python3
"""Exercise publication race, final-proof preservation and corrupt-head refusal."""
import hashlib,json,subprocess,tempfile,unittest
from pathlib import Path
TOOL=Path(__file__).with_name('clean-checkpoints.py')
class Cleanup(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)/'artifacts/local/run';self.root.mkdir(parents=True);self.audit=Path(self.tmp.name)/'audit.jsonl'
 def tearDown(self):self.tmp.cleanup()
 def chain(self,tic):
  p=self.root/f'evm.checkpoint-{tic}.chain.gz';p.write_bytes(f'opaque checkpoint {tic}'.encode());return p
 def publish(self,tic,chain):
  (self.root/'evm.checkpoint.json').write_text(json.dumps(dict(schemaVersion=2,tic=tic,chain=dict(file=str(chain),sha256=hashlib.sha256(chain.read_bytes()).hexdigest()),receipts={})))
 def run_tool(self):return subprocess.run(['python3',str(TOOL),str(self.root),'--audit-log',str(self.audit)],capture_output=True,text=True)
 def test_unpublished_future_survives_until_pointer_publication(self):
  old=self.chain(0);head=self.chain(1);future=self.chain(2);self.publish(1,head)
  proof=self.root/'evm.replay-receipts.json.gz';proof.write_bytes(b'final proof')
  self.assertEqual(self.run_tool().returncode,0);self.assertFalse(old.exists());self.assertTrue(head.exists());self.assertTrue(future.exists());self.assertEqual(proof.read_bytes(),b'final proof')
  self.publish(2,future);self.assertEqual(self.run_tool().returncode,0);self.assertFalse(head.exists());self.assertTrue(future.exists());self.assertTrue(proof.exists())
 def test_corrupt_head_refuses_all_removal(self):
  old=self.chain(0);head=self.chain(1);self.publish(1,head);head.write_bytes(b'corrupted')
  self.assertNotEqual(self.run_tool().returncode,0);self.assertTrue(old.exists());self.assertEqual(head.read_bytes(),b'corrupted')
 def test_relocated_pointer_resolves_hash_bound_siblings(self):
  head=self.chain(1);self.publish(1,head);p=self.root/'evm.checkpoint.json';data=json.loads(p.read_text());data['chain']['file']='/old/relocated/'+head.name;p.write_text(json.dumps(data))
  self.assertEqual(self.run_tool().returncode,0);self.assertTrue(head.exists())
if __name__=='__main__':unittest.main()
