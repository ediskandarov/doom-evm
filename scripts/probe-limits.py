#!/usr/bin/env python3
"""Bounded experiments against pinned Anvil; all code is ordinary EVM bytecode."""
import hashlib, json, pathlib, socket, subprocess, time, urllib.error, urllib.request
from execution_budget import CONFIG, execution_env, load_gas_budget
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'local'
OUT.mkdir(parents=True, exist_ok=True)
ANVIL = str(ROOT / '.toolchain/bin/anvil')
BUDGET = load_gas_budget()
CHILD_ENV = execution_env()
BUDGET_IDENTITY = dict(BUDGET, config_path='execution-budget.json',
                       config_sha256=hashlib.sha256(CONFIG.read_bytes()).hexdigest(),
                       python_helper_sha256=hashlib.sha256((ROOT/'scripts/execution_budget.py').read_bytes()).hexdigest())

class RpcError(Exception): pass

def rpc(port, method, params=()):
    request = urllib.request.Request(f'http://127.0.0.1:{port}', json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':list(params)}).encode(), {'Content-Type':'application/json'})
    with urllib.request.urlopen(request, timeout=30) as response:
        result = json.load(response)
    if 'error' in result: raise RpcError(json.dumps(result['error']))
    return result['result']

def transact(port, account, data, gas, to=None, allow_pending=False):
    tx={'from':account,'data':'0x'+data.hex(),'gas':hex(gas)}
    if to: tx['to']=to
    start=time.perf_counter()
    try:
        txhash=rpc(port,'eth_sendTransaction',[tx])
        for _ in range(100):
            receipt=rpc(port,'eth_getTransactionReceipt',[txhash])
            if receipt:
                return {'accepted':True,'success':receipt['status']=='0x1','gas_used':int(receipt['gasUsed'],16),'address':receipt['contractAddress'],'tx_hash':txhash,'elapsed_ms':(time.perf_counter()-start)*1000}
            time.sleep(.02)
        if allow_pending:
            pending=rpc(port,'eth_getTransactionByHash',[txhash])
            dropped=rpc(port,'anvil_dropTransaction',[txhash])
            return {'accepted':True,'success':False,'no_receipt_after_ms':(time.perf_counter()-start)*1000,'transaction_lookup':pending,'tx_hash':txhash,'dropped':dropped}
        raise RuntimeError('receipt timeout')
    except RpcError as error:
        return {'accepted':False,'success':False,'error':str(error),'elapsed_ms':(time.perf_counter()-start)*1000}

def initcode(runtime):
    # PUSH3 length; PUSH1 14; PUSH0 CODECOPY; PUSH3 length; PUSH0 RETURN.
    n=len(runtime).to_bytes(3,'big')
    return b'\x62'+n+b'\x60\x0e\x5f\x39\x62'+n+b'\x5f\xf3'+runtime

def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1',0)); return s.getsockname()[1]

def run(label, relaxed, memory_limit=1073741824):
    port=free_port()
    args=[ANVIL,'--host','127.0.0.1','--port',str(port),'--hardfork','cancun','--memory-limit',str(memory_limit),'--quiet']
    if relaxed: args += ['--disable-code-size-limit','--disable-block-gas-limit']
    else: args += ['--gas-limit',str(BUDGET['gasLimit'])]
    with (OUT / f'limits-{label}.log').open('w') as logfile:
        proc=subprocess.Popen(args, env=CHILD_ENV, stdout=logfile, stderr=subprocess.STDOUT)
        try:
            for _ in range(150):
                if proc.poll() is not None: raise RuntimeError(f'Anvil exited: {(OUT / ("limits-"+label+".log")).read_text()}')
                try:
                    account=rpc(port,'eth_accounts')[0]; break
                except (OSError,urllib.error.URLError): time.sleep(.05)
            else: raise RuntimeError('Anvil startup timeout')
            if relaxed:
                rpc(port,'anvil_setBlockGasLimit',[BUDGET['gasHex']])
                rpc(port,'evm_mine')
            results={'post_start_rpc':(['anvil_setBlockGasLimit',BUDGET['gasHex']] if relaxed else None),'initialization_mined_block':relaxed,'args':args[1:],'client':rpc(port,'web3_clientVersion'),'block_gas_limit':int(rpc(port,'eth_getBlockByNumber',['latest',False])['gasLimit'],16)}
            assert results['block_gas_limit']==BUDGET['gasLimit']
            results['gas_above_block']=transact(port,account,b'',BUDGET['gasLimit']+1,account,allow_pending=True)
            # These smaller explicit gas cases isolate code/memory limits.
            # They remain deliberate while the block budget is configurable.
            if memory_limit > 1024:
                for n in (25000,50000):
                    deployed=transact(port,account,initcode(b'\x00'*n),100000000)
                    if deployed['success']:
                        deployed['runtime_bytes']=len(bytes.fromhex(rpc(port,'eth_getCode',[deployed['address'],'latest'])[2:]))
                        assert deployed['runtime_bytes']==n
                    results[f'deploy_{n}']=deployed
            # Touch word at offset 65536; then return the stored word. ~64KB memory, not 1GiB.
            deployed=transact(port,account,initcode(bytes.fromhex('602a6201000052602062010000f3')),1000000)
            assert deployed['success']
            try:
                output=rpc(port,'eth_call',[{'to':deployed['address'],'data':'0x','gas':hex(1000000)},'latest'])
                results['memory_64k']={'success':True,'value':int(output,16)}
            except RpcError as error: results['memory_64k']={'success':False,'error':str(error)}
            try:
                output=rpc(port,'eth_call',[{'to':deployed['address'],'data':'0x','gas':hex(BUDGET['gasLimit']+1)},'latest'])
                results['call_gas_above_block']={'success':True,'value':int(output,16)}
            except RpcError as error: results['call_gas_above_block']={'success':False,'error':str(error)}
            if relaxed: assert results['call_gas_above_block']=={'success':True,'value':42}
            if memory_limit > 1024:
                assert results['memory_64k']=={'success':True,'value':42}
                assert results['deploy_25000']['success'] == relaxed
                assert results['deploy_50000']['success'] == relaxed
                if not relaxed: assert 'max initcode size exceeded' in results['deploy_50000']['error']
            else: assert not results['memory_64k']['success']
            return results
        finally:
            proc.terminate()
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()

results={'scope':'Phase 0 resource-limit probes; synthetic EVM programs, no DOOM renderer','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'execution_budget':BUDGET_IDENTITY,'control':run('control',False),'control_1k_memory':run('memory-control',False,1024),'relaxed':run('relaxed',True)}
(OUT/'runtime-limits.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
