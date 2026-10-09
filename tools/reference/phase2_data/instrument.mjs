// Source-mapped instrumentation for a separate ordinarily deployed measurement probe.
// GAS and MSIZE both cost two gas and push one word. No layout, jumps or resource bytes change.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export function instrumentGasMarkers(artifact,source,functionName='memorySize') {
  const beginning=source.indexOf(`function ${functionName}(`);assert(beginning>=0,'marker helper absent');
  let ending=source.indexOf('{',beginning)+1,depth=1;
  while(depth){if(source[ending]==='{')depth++;else if(source[ending]==='}')depth--;ending++;assert(ending<=source.length);}
  const original=Buffer.from(artifact.deployedBytecode.object.replace(/^0x/,''),'hex'),runtime=Buffer.from(original);
  const mappings=artifact.deployedBytecode.sourceMap.split(';');let previous=['0','0','-1','',''];let instruction=0;const patches=[];
  for(let pc=0;pc<runtime.length;) {
    const fields=(mappings[instruction]??'').split(':');const values=previous.map((v,i)=>fields[i]||v);previous=values;
    const [start,length,file]=values.slice(0,3).map(Number),op=runtime[pc];
    if(op===0x5a&&file===artifact.id&&start>=beginning&&start+length<=ending) {
      patches.push({pc,sourceStart:start,sourceLength:length,line:source.slice(0,start).split('\n').length,sourceText:source.slice(start,start+length),before:'GAS 0x5a',after:'MSIZE 0x59'});
      runtime[pc]=0x59;
    }
    pc+=op>=0x60&&op<=0x7f?1+op-0x5f:1;instruction++;
  }
  assert(patches.length>0&&patches.length<=32,'unexpected marker count');
  const creation=Buffer.from(artifact.bytecode.object.replace(/^0x/,''),'hex');
  const runtimeAt=creation.indexOf(original);assert(runtimeAt>=0,'runtime not embedded verbatim in creation');assert.equal(creation.indexOf(original,runtimeAt+1),-1,'ambiguous runtime embedding');
  for(const p of patches){assert.equal(creation[runtimeAt+p.pc],0x5a);creation[runtimeAt+p.pc]=0x59;}
  assert.equal(runtime.length,original.length);
  assert.deepEqual([...runtime.keys()].filter(i=>runtime[i]!==original[i]),patches.map(p=>p.pc),'unexpected bytecode changes');
  return {creation,runtime,report:{functionName,sourceId:artifact.id,sourceSha256:sha(Buffer.from(source)),originalRuntimeSha256:sha(original),instrumentedRuntimeSha256:sha(runtime),runtimeBytes:runtime.length,runtimeOffsetInCreation:runtimeAt,patches,semantics:'Separate probe deployment only. GAS→MSIZE, identical2gas and +1stack effect, unchanged bytecode layout/jump destinations. Operation gas and output digests must match ordinary uninstrumented deployment.'}};
}

// Memory expansion reconstructed from operands, for bounded trace calibration only.
export function traceMemory(logs) {
  let high=0n;const marks=[];
  const range=(offset,size)=>{if(size){const end=(offset+size+31n)/32n*32n;if(end>high)high=end;}};
  for(const log of logs){
    assert.equal(log.depth,1,'nested memory frame is unsupported');
    const at=n=>BigInt('0x'+log.stack.at(-n).replace(/^0x/,''));
    switch(log.op){
      case'MSIZE':marks.push({pc:log.pc,bytes:Number(high)});break;
      case'MLOAD':case'MSTORE':range(at(1),32n);break;
      case'MSTORE8':range(at(1),1n);break;
      case'MCOPY':range(at(1),at(3));range(at(2),at(3));break;
      case'CALLDATACOPY':case'CODECOPY':case'RETURNDATACOPY':range(at(1),at(3));break;
      case'EXTCODECOPY':range(at(2),at(4));break;
      case'SHA3':case'KECCAK256':case'RETURN':case'REVERT':case'LOG0':case'LOG1':case'LOG2':case'LOG3':case'LOG4':range(at(1),at(2));break;
      case'CALL':case'CALLCODE':range(at(4),at(5));range(at(6),at(7));break;
      case'STATICCALL':case'DELEGATECALL':range(at(3),at(4));range(at(5),at(6));break;
      case'CREATE':case'CREATE2':range(at(2),at(3));break;
    }
  }
  return {highWaterBytes:Number(high),markers:marks};
}
