#!/usr/bin/env python3
"""Infrastructure tests; native equivalence is independently checked by reference.py."""
import copy, hashlib, json, pathlib, struct, subprocess, sys, tempfile, unittest
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
    def wad_metadata(self, pixels):
        metadata=copy.deepcopy(self.meta)
        metadata.update(scope='world-view',width=len(pixels),height=1,frameSha256=hashlib.sha256(pixels).hexdigest())
        metadata['resourceIdentity']['wadSha256']='1'*64
        metadata['provenance']={'kind':'wad','wadName':'fabricated-schema-test.wad','wadSha256':'1'*64,'upstreamCommit':'a'*40,'license':'schema fixture only','map':'E1M1','build':{'compiler':'test','version':'test','target':'test','flags':[],'patchSha256':'2'*64,'harnessSha256':'3'*64,'integerSemantics':'test','doubleSemantics':'test'}}
        return metadata
    def test_reference_scope_and_identity(self):
        pixels=b'x'; synthetic=copy.deepcopy(self.meta)
        synthetic.update(width=1,height=1,frameSha256=hashlib.sha256(pixels).hexdigest())
        synthetic['resourceIdentity']['wadSha256']='1'*64
        with self.assertRaisesRegex(ValueError,'Synthetic reference'): pixel_diff.validate_reference(synthetic,pixels)
        for mutation in [lambda m:m.update(scope='synthetic-transport'),lambda m:m['resourceIdentity'].update(wadSha256='0'*64),lambda m:m['provenance'].update(wadSha256='2'*64)]:
            metadata=self.wad_metadata(pixels); mutation(metadata)
            with self.assertRaises(ValueError): pixel_diff.validate_reference(metadata,pixels)
    def test_compare_rejects_distinct_maps_and_upstream_but_permits_builds(self):
        pixels=b'x'; expected=self.wad_metadata(pixels)
        with tempfile.TemporaryDirectory() as path:
            folder=pathlib.Path(path); (folder/'pixels.bin').write_bytes(pixels); (folder/'expected.json').write_text(json.dumps(expected))
            cmd=[sys.executable,str(reference.HERE/'pixel_diff.py'),'compare','--expected',str(folder/'pixels.bin'),'--actual',str(folder/'pixels.bin'),'--reference',str(folder/'expected.json'),'--actual-reference',str(folder/'actual.json')]
            for key,value in [('map','E1M2'),('upstreamCommit','b'*40)]:
                actual=copy.deepcopy(expected); actual['provenance'][key]=value; (folder/'actual.json').write_text(json.dumps(actual))
                result=subprocess.run(cmd,text=True,capture_output=True)
                self.assertNotEqual(result.returncode,0); self.assertIn('settings differ',result.stderr)
            actual=copy.deepcopy(expected); actual['provenance']['build']['compiler']='alternate-test'; (folder/'actual.json').write_text(json.dumps(actual))
            result=subprocess.run(cmd,text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr); self.assertEqual(json.loads(result.stdout)['mismatchCount'],0)
    def test_bsp_root_index_boundary(self):
        with tempfile.TemporaryDirectory() as path:
            directory=pathlib.Path(path); reference.build(directory)
            node=bytes(24)+struct.pack('<HH',32768,32768)
            (directory/'boundary.bin').write_bytes(node*32768)
            rows=[reference.row('R_PointInSubsector',[0,0]),reference.row('BSPPath',[0,0])]
            values=reference.evaluate(directory,rows,[directory/'boundary.bin',1])
            self.assertEqual([r['outputs'] for r in values],[[0],[32767,32768]])
            (directory/'oversized.bin').write_bytes(node*32769)
            result=subprocess.run([str(directory/'O2'),str(directory/'oversized.bin'),'1'],capture_output=True)
            self.assertEqual(result.returncode,2)
    def test_original_edges_and_empty_bsp(self):
        with tempfile.TemporaryDirectory() as path:
            directory=pathlib.Path(path); reference.build(directory)
            rows=reference.run(directory/'O2',[reference.row('FixedDiv',[0,0]),reference.row('FixedDiv2',[1,0]),reference.row('FixedMul',[-1,1]),reference.row('SlopeDiv',[536870912,512])])
            self.assertEqual([(r['status'],r['outputs']) for r in rows],[('ok',[2147483647]),('error',[]),('ok',[-1]),('ok',[0])])
            (directory/'empty.bin').write_bytes(b'')
            values=reference.evaluate(directory,[reference.row('R_PointInSubsector',[0,0]),reference.row('BSPPath',[0,0])],[directory/'empty.bin',1])
            self.assertEqual([r['outputs'] for r in values],[[0],[32768]])
if __name__=='__main__': unittest.main()
