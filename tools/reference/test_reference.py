#!/usr/bin/env python3
"""Infrastructure tests; native equivalence is independently checked by reference.py."""
import copy, hashlib, json, pathlib, subprocess, sys, tempfile, unittest
import pixel_diff
import reference
ROOT=reference.ROOT
class ReferenceTests(unittest.TestCase):
    def setUp(self):
        self.vectors=json.loads((reference.FIXTURES/'numeric-v1.json').read_text())
        self.meta=json.loads((ROOT/'test/fixtures/phase0/reference.json').read_text())
    def test_vector_semantics(self): reference.validate_vectors(self.vectors)
    def test_invalid_signature_and_status(self):
        mutations=[lambda d:d['vectors'][0].update(inputs=[1]),lambda d:d['vectors'][0].update(inputs=[True,1]),lambda d:d['vectors'][0].update(inputs=[2147483648,1]),lambda d:d['vectors'][0].update(outputs=[]),lambda d:d['vectors'][0].update(status='undefined',outputs=[],note='fake'),lambda d:d.update(scope='geometry-synthetic'),lambda d:d.update(wadSha256='1'*64),lambda d:d.update(map='E1M1')]
        for mutate in mutations:
            bad=copy.deepcopy(self.vectors); mutate(bad)
            with self.assertRaises(ValueError): reference.validate_vectors(bad)
    def test_unsigned_and_nonok(self):
        for fn,change in [('SlopeDiv',{'inputs':[-1,512]}),('FixedDiv2',{'status':'error','outputs':[0]})]:
            bad=copy.deepcopy(self.vectors); bad['vectors']=[next(r for r in bad['vectors'] if r['function']==fn)]; bad['vectors'][0].update(change)
            with self.assertRaises(ValueError): reference.validate_vectors(bad)
    def test_geometry_trace_validation(self):
        value=json.loads((reference.FIXTURES/'geometry-synthetic-v1.json').read_text()); reference.validate_vectors(value)
        value['vectors']=[next(r for r in value['vectors'] if r['function']=='BSPPath')]; value['vectors'][0]['outputs'][-1]=3
        with self.assertRaises(ValueError): reference.validate_vectors(value)
    def test_pixel_locations(self):
        result=pixel_diff.compare(bytes([1,2,3,4,5,6]),bytes([1,9,3,4,5,0]),3,2)
        self.assertEqual(result['mismatchCount'],2)
        self.assertEqual(result['mismatches'],[{'x':1,'y':0,'expected':2,'actual':9},{'x':2,'y':1,'expected':6,'actual':0}])
        self.assertEqual(pixel_diff.compare(b'abc',b'abc',3,1)['mismatchCount'],0)
    def test_pixel_dimensions(self):
        for args in [(b'a',b'',1,1),(b'a',b'a',0,1),(b'aa',b'aa',1,1)]:
            with self.assertRaises(ValueError): pixel_diff.compare(*args)
    def test_reference_integrity(self):
        pixels=bytes([7,9]); self.meta.update(width=2,height=1,frameSha256=hashlib.sha256(pixels).hexdigest())
        pixel_diff.validate_reference(self.meta,pixels)
        with self.assertRaises(ValueError): pixel_diff.validate_reference(self.meta,b'xx')
        self.meta['scope']='world-view'
        with self.assertRaises(ValueError): pixel_diff.validate_reference(self.meta,pixels)
    def test_record_and_comparison_cli(self):
        with tempfile.TemporaryDirectory() as path:
            folder=pathlib.Path(path); pixels=bytes([1,2,3,4]); actual=bytes([1,9,3,4]); self.meta.update(width=2,height=2,frameSha256=hashlib.sha256(pixels).hexdigest())
            (folder/'source.bin').write_bytes(pixels); (folder/'source.json').write_text(json.dumps(self.meta))
            cmd=[sys.executable,str(reference.HERE/'pixel_diff.py')]
            subprocess.run([*cmd,'record','--pixels',str(folder/'source.bin'),'--reference',str(folder/'source.json'),'--output',str(folder/'record')],check=True,capture_output=True)
            self.assertEqual((folder/'record/pixels.bin').read_bytes(),pixels)
            self.meta['frameSha256']=hashlib.sha256(actual).hexdigest(); (folder/'actual.bin').write_bytes(actual); (folder/'actual.json').write_text(json.dumps(self.meta))
            command=[*cmd,'compare','--expected',str(folder/'source.bin'),'--actual',str(folder/'actual.bin'),'--reference',str(folder/'source.json'),'--actual-reference',str(folder/'actual.json')]
            result=subprocess.run(command,capture_output=True,text=True); self.assertEqual(result.returncode,1); self.assertEqual(json.loads(result.stdout)['mismatchCount'],1)
            self.meta['camera']['angle']+=1; (folder/'actual.json').write_text(json.dumps(self.meta)); result=subprocess.run(command,capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0); self.assertIn('settings differ',result.stderr)
    def test_original_edges_and_empty_bsp(self):
        with tempfile.TemporaryDirectory() as path:
            directory=pathlib.Path(path); reference.build(directory)
            rows=reference.run(directory/'O2',[reference.row('FixedDiv',[0,0]),reference.row('FixedDiv2',[1,0]),reference.row('FixedMul',[-1,1]),reference.row('SlopeDiv',[536870912,512])])
            self.assertEqual([(r['status'],r['outputs']) for r in rows],[('ok',[2147483647]),('error',[]),('ok',[-1]),('ok',[0])])
            (directory/'empty.bin').write_bytes(b'')
            values=reference.evaluate(directory,[reference.row('R_PointInSubsector',[0,0]),reference.row('BSPPath',[0,0])],[directory/'empty.bin',1])
            self.assertEqual([r['outputs'] for r in values],[[0],[32768]])
if __name__=='__main__': unittest.main()
