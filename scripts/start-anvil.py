#!/usr/bin/env python3
"""Launch pinned Anvil with relaxed limits and explicit 1e9 block gas via RPC."""
import argparse, json, os, pathlib, signal, subprocess, sys, time, urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check',action='store_true',help='Verify startup and terminate the child')
parser.add_argument('--quiet',action='store_true')
options=parser.parse_args()
port=int(os.environ.get('ANVIL_PORT','8545'))
args=[str(ROOT/'.toolchain/bin/anvil'),'--host','127.0.0.1','--port',str(port),'--chain-id','31337','--hardfork','cancun','--disable-code-size-limit','--disable-block-gas-limit','--memory-limit','1073741824',*(['--quiet'] if options.quiet else [])]
# Avoid attaching to an existing node if our child cannot bind the port.
import socket
with socket.socket() as check:
    check.bind(('127.0.0.1',port))
proc=subprocess.Popen(args)
def stop(signum, frame):
    if proc.poll() is None: proc.send_signal(signum)
signal.signal(signal.SIGINT,stop)
signal.signal(signal.SIGTERM,stop)
def rpc(method,params):
    req=urllib.request.Request(f'http://127.0.0.1:{port}',json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),{'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=2) as r: data=json.load(r)
    if 'error' in data: raise RuntimeError(data['error'])
    return data['result']
try:
    for _ in range(100):
        if proc.poll() is not None: raise RuntimeError(f'Anvil exited with {proc.returncode}')
        try:
            rpc('web3_clientVersion',[]); break
        except OSError: time.sleep(.05)
    else: raise RuntimeError('Anvil startup timeout')
    rpc('anvil_setBlockGasLimit',[hex(1000000000)])
    rpc('evm_mine',[])
    assert int(rpc('eth_getBlockByNumber',['latest',False])['gasLimit'],16)==1000000000
    print(f'DOOM EVM ready: http://127.0.0.1:{port}, Cancun, block gas 1e9, relaxed code/block checks, memory 1GiB',flush=True)
    if options.check: sys.exit(0)
    sys.exit(proc.wait())
finally:
    if proc.poll() is None:
        proc.terminate()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: proc.kill(); proc.wait()
