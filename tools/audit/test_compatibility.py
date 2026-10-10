"""Integrity regressions for the separate post-acceptance evidence audit."""
import importlib.util,json,tempfile,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('compatibility_audit',HERE/'compatibility.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
class CompatibilityAuditTest(unittest.TestCase):
 def setUp(self):
  self.checkpoint=json.loads((ROOT/'artifacts/phase3/drawbounds-compatibility.json').read_text())
  self.directory=tempfile.TemporaryDirectory(dir=ROOT/'artifacts/local',prefix='compatibility-audit-test-');self.path=Path(self.directory.name)/'checkpoint.json'
 def tearDown(self):self.directory.cleanup()
 def run_audit(self):
  self.path.write_text(json.dumps(self.checkpoint));return audit.build(str(self.path.relative_to(ROOT)))
 def test_valid_checkpoint_binds_history_and_current_code_separately(self):
  result=self.run_audit();self.assertTrue(result['pass']);self.assertEqual(len(result['functionBindings']),388);self.assertEqual(len(result['changedEngineSources']),5)
  self.assertIn('frozen revision only',result['historicalM2M3'])
 def test_missing_regression_category_rejects_partial_evidence(self):
  del self.checkpoint['regressionGates']['phase1']
  with self.assertRaisesRegex(AssertionError,'missing regression'):self.run_audit()
 def test_failed_regression_cannot_be_published(self):
  self.checkpoint['regressionGates']['capturedInitialized']['pass']=False
  with self.assertRaisesRegex(AssertionError,'incomplete regressions'):self.run_audit()
 def test_tampered_current_source_binding_rejects(self):
  self.checkpoint['sourceHashes']['src/doom/z_zone_backing.sol']='0'*64
  with self.assertRaises(AssertionError):self.run_audit()
 def test_historical_certificate_hash_cannot_be_relabelled(self):
  self.checkpoint['historicalAcceptance']['sha256']='0'*64
  with self.assertRaisesRegex(AssertionError,'historical certificate'):self.run_audit()
if __name__=='__main__':unittest.main()
