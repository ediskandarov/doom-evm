import test from 'node:test';
import assert from 'node:assert/strict';
import {instrumentGasMarkers,traceMemory} from './instrument.mjs';
const source='function memorySize() private view returns(uint256 size) { assembly { size := gas() } } function other() { assembly { pop(gas()) } }';
const marker=source.indexOf('gas()'),other=source.lastIndexOf('gas()');
const runtime='605a505a505a00'; // PUSH1 payload GAS byte must never be interpreted as an opcode.
const artifact={id:1,bytecode:{object:'0x00'+runtime},deployedBytecode:{object:'0x'+runtime,sourceMap:[marker,marker,marker,marker,other,other].map(p=>`${p}:5:1:-:0`).join(';')}};
test('patch only source-mapped marker opcodes, never PUSH payload or unrelated GAS',()=>{
  const result=instrumentGasMarkers(artifact,source);assert.equal(result.runtime.toString('hex'),'605a5059505a00');
  assert.deepEqual(result.report.patches.map(p=>p.pc),[3]);assert.equal(result.creation.toString('hex'),'00605a5059505a00');
});
test('missing marker source mapping or ambiguous runtime embedding fails closed',()=>{
  assert.throws(()=>instrumentGasMarkers({...artifact,id:2},source));
  assert.throws(()=>instrumentGasMarkers({...artifact,bytecode:{object:'0x'+runtime+runtime}},source));
});
test('trace calibration honors zero-length copies and both MCOPY ranges',()=>{
  const log=(op,stack)=>({op,depth:1,pc:0,stack:stack.map(n=>n.toString(16))});
  const result=traceMemory([log('CALLDATACOPY',[0n,0n,0xffffn]),log('MCOPY',[32n,0x121n,0n]),log('MSIZE',[])]);
  assert.equal(result.highWaterBytes,352);assert.equal(result.markers[0].bytes,352);
  assert.throws(()=>traceMemory([{op:'STOP',depth:2,stack:[]}]))
});
