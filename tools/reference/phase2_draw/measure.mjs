#!/usr/bin/env node
// Measure ordinary EVM execution. Memory high-water is reconstructed from the
// stack operands of ALL memory-expanding opcodes, without huge memory snapshots.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawn, spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const output = path.resolve(process.argv[2] ?? path.join(root, 'artifacts/local/phase2-draw-measurements.json'));
const port = Number(process.env.DRAW_ANVIL_PORT ?? 18557);
assert(Number.isInteger(port) && port > 1024 && port < 65536);
const build = spawnSync(path.join(root, '.toolchain/bin/forge'), ['build'], {cwd: root, encoding: 'utf8'});
if(build.status !== 0) throw new Error(build.stderr + build.stdout);
const artifact = JSON.parse(fs.readFileSync(path.join(root, 'out/r_draw.t.sol/RDrawTest.json')));
const server = spawn(path.join(root, '.toolchain/bin/anvil'), ['--host','127.0.0.1','--port',String(port),'--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824','--silent'], {cwd:root, stdio:['ignore','ignore','pipe']});
let stderr = ''; server.stderr.on('data', chunk => stderr += chunk);
let id = 0;
async function rpc(method, params=[]) {
  const response = await fetch(`http://127.0.0.1:${port}`, {method:'POST',headers:{'content-type':'application/json'}, body:JSON.stringify({jsonrpc:'2.0',id:++id,method,params})});
  const data = await response.json(); if(data.error) throw new Error(`${method}: ${JSON.stringify(data.error)}`); return data.result;
}
function traceMemory(logs) {
  let high = 0n; const gasBoundaries=[]; let previousDepth = 1; let calls=0;
  const counts={};
  function range(offset,size) { if(size) {const end=((offset+size+31n)/32n)*32n; if(end>high) high=end;} }
  for(const log of logs) {
    // Only SHA-256 precompile calls occur and no callee instruction frame exists.
    // Fail rather than silently conflate distinct EVM memory frames.
    assert.equal(log.depth,1,`unexpected nested interpreter frame after depth ${previousDepth}`); previousDepth=log.depth;
    const stack=log.stack; const at=n=>BigInt('0x'+stack.at(-n).replace(/^0x/,''));
    counts[log.op]=(counts[log.op]??0)+1;
    switch(log.op) {
      case 'GAS': gasBoundaries.push({highWaterBytes:Number(high),gas:Number(log.gas)}); break;
      case 'MLOAD': case 'MSTORE': range(at(1),32n); break;
      case 'MSTORE8': range(at(1),1n); break;
      case 'MCOPY': range(at(1),at(3)); range(at(2),at(3)); break;
      case 'CALLDATACOPY': case 'CODECOPY': case 'RETURNDATACOPY': range(at(1),at(3)); break;
      case 'EXTCODECOPY': range(at(2),at(4)); break;
      case 'SHA3': case 'KECCAK256': case 'RETURN': case 'REVERT':
      case 'LOG0': case 'LOG1': case 'LOG2': case 'LOG3': case 'LOG4': range(at(1),at(2)); break;
      case 'CALL': case 'CALLCODE': range(at(4),at(5)); range(at(6),at(7)); ++calls; break;
      case 'STATICCALL': case 'DELEGATECALL': range(at(3),at(4)); range(at(5),at(6)); ++calls; break;
      case 'CREATE': case 'CREATE2': range(at(2),at(3)); break;
    }
  }
  assert(gasBoundaries.length>=2); // Solidity gasleft around the primitive, before final SHA-256.
  return {wholeCallHighWaterBytes:Number(high),primitiveBeforeBytes:gasBoundaries[0].highWaterBytes,primitiveAfterBytes:gasBoundaries[1].highWaterBytes,primitiveGasFromTrace:gasBoundaries[0].gas-gasBoundaries[1].gas,opcodeCount:logs.length,externalCalls:calls,memoryOpcodes:Object.fromEntries(Object.entries(counts).filter(([op])=>['MLOAD','MSTORE','MSTORE8','MCOPY','STATICCALL','CALL','RETURN','KECCAK256'].includes(op)))};
}
try {
  let ready=false;
  for(let attempt=0;attempt<100;attempt++) {
    if(server.exitCode !== null) throw new Error('Anvil exited: '+stderr);
    try { await rpc('web3_clientVersion'); ready=true;break; } catch { await new Promise(r=>setTimeout(r,50)); }
  }
  assert(ready,'Anvil did not start');
  await rpc('anvil_setBlockGasLimit',['0x3b9aca00']); await rpc('evm_mine');
  const [from]=await rpc('eth_accounts');
  // Calibrate the decoder against literal MSIZE in a small ordinary EVM contract.
  // Solc's viaIR optimizer disallows MSIZE, so this independent probe exercises
  // MSTORE/MSTORE8/MCOPY/KECCAK256/CODECOPY/MLOAD/zero-length copy/STATICCALL/RETURN.
  const calibrationRuntime='5a50606060405260aa6020536020608060a05e602060c02050601060006101003961012c51506000600061ffff376020610180602060006002620186a0fa505a505960005260206000f3';
  const calibrationLength=(calibrationRuntime.length/2).toString(16).padStart(2,'0');
  const calibrationCreation='0x60'+calibrationLength+'600c60003960'+calibrationLength+'6000f3'+calibrationRuntime;
  const calibrationTx=await rpc('eth_sendTransaction',[{from,data:calibrationCreation,gas:'0x989680'}]);
  let calibrationReceipt;
  for(let n=0;n<100;n++) { calibrationReceipt=await rpc('eth_getTransactionReceipt',[calibrationTx]); if(calibrationReceipt)break; await new Promise(r=>setTimeout(r,50)); }
  assert.equal(calibrationReceipt?.status,'0x1');
  const calibrationCall={from,to:calibrationReceipt.contractAddress,gas:'0x989680'};
  const calibrationResult=Number(BigInt(await rpc('eth_call',[calibrationCall,'latest'])));
  const calibrationTrace=await rpc('debug_traceCall',[calibrationCall,'latest',{disableStorage:true,disableStack:false,enableMemory:false}]);
  const calibration=traceMemory(calibrationTrace.structLogs);
  assert.equal(calibration.wholeCallHighWaterBytes,calibrationResult,'decoder disagrees with actual MSIZE');
  assert.equal(calibrationResult,416,'unexpected calibration footprint');
  const tx=await rpc('eth_sendTransaction',[{from,data:artifact.bytecode.object,gas:'0x5f5e100'}]);
  let receipt;
  for(let attempt=0;attempt<100;attempt++) { receipt=await rpc('eth_getTransactionReceipt',[tx]); if(receipt) break; await new Promise(r=>setTimeout(r,50)); }
  assert(receipt,'deployment did not mine'); assert.equal(receipt.status,'0x1');
  const measurements=[];
  for(let op=0;op<6;op++) {
    const call={from,to:receipt.contractAddress,data:'0x'+artifact.methodIdentifiers['probe(uint32)']+op.toString(16).padStart(64,'0'),gas:'0x5f5e100'};
    const result=await rpc('eth_call',[call,'latest']);
    const words=result.slice(2).match(/.{64}/g); assert.equal(words.length,4);
    const trace=await rpc('debug_traceCall',[call,'latest',{disableStorage:true,disableStack:false,enableMemory:false,enableReturnData:false}]);
    assert(!trace.failed,'trace execution failed');
    const measured=traceMemory(trace.structLogs);
    const item={operation:['R_DrawColumn','R_DrawColumnLow','R_DrawTranslatedColumn','R_DrawFuzzColumn','R_DrawSpan','R_DrawSpanLow'][op],pixelsWritten:[200,400,200,198,320,318][op],drawGas:Number(BigInt('0x'+words[0])),allocatorBefore:Number(BigInt('0x'+words[1])),allocatorAfter:Number(BigInt('0x'+words[2])),frameSha256:words[3],...measured};
    assert.equal(item.drawGas,item.primitiveGasFromTrace,'gasleft and trace disagree');
    measurements.push(item);
    console.log(`${item.operation}: ${item.drawGas} gas; EVM memory ${item.primitiveBeforeBytes} -> ${item.primitiveAfterBytes} bytes`);
  }
  const sourceHashes=Object.fromEntries(['src/doom/r_draw.sol','src/doom/r_state.sol','test/unit/r_draw.t.sol','tools/reference/phase2_draw/measure.mjs','foundry.toml'].map(p=>[p,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex')]));
  const report={calibration:{actualMsize:calibrationResult,derivedHighWater:calibration.wholeCallHighWaterBytes,runtime:calibrationRuntime},deployedBytecodeSha256:crypto.createHash('sha256').update(Buffer.from(artifact.deployedBytecode.object.replace(/^0x/,''),'hex')).digest('hex'),kind:'phase2-draw-evm-measurements',client:await rpc('web3_clientVersion'),compiler:'solc 0.8.37 viaIR optimizer 200 Cancun',sourceHashes,scope:'Primitive gas and actual EVM memory expansion from stack-only opcode trace. Setup and final framebuffer SHA excluded from primitive segment; whole-call high-water includes them. Local synthetic input patterns match original-C fixtures. No whole-renderer performance claim.',measurements};
  fs.mkdirSync(path.dirname(output),{recursive:true}); fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
  console.log(`Saved ${output}`);
} finally { server.kill('SIGTERM'); }
