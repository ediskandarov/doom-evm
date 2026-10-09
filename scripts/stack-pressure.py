#!/usr/bin/env python3
"""Compile only the shape spike through both solc pipelines; retain actual diagnostics."""
import hashlib
import json
import pathlib
import platform
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = 'src/support/StackPressure.sol'
SOLC = ROOT / '.toolchain/bin/solc'
OUT = ROOT / 'artifacts/local/stack'
OUT.mkdir(parents=True, exist_ok=True)
source_text = (ROOT / SOURCE).read_text()
version = subprocess.check_output([str(SOLC), '--version'], text=True).strip()
if '0.8.37+commit.f401782d' not in version:
    raise SystemExit('Expected pinned solc 0.8.37+commit.f401782d; got ' + version)
report = {
    'experiment': 'synthetic R_StoreWallRange shape; not a port or C-equivalence result',
    'upstream_commit': 'a77dfb96cb91780ca334d0d4cfd86957558007e0',
    'source_sha256': hashlib.sha256(source_text.encode()).hexdigest(),
    'compiler': version,
    'host': platform.platform(),
    'settings': {'optimizer': {'enabled': True, 'runs': 200}, 'evmVersion': 'cancun'},
    'command': '.toolchain/bin/solc --standard-json (input assembled by scripts/stack-pressure.py)',
    'results': [],
}
for via_ir in [True, False]:
    name = 'via-ir' if via_ir else 'legacy'
    settings = dict(report['settings'], viaIR=via_ir,
                    outputSelection={'*': {'*': ['evm.bytecode.object', 'evm.deployedBytecode.object']}})
    request = {'language': 'Solidity', 'sources': {SOURCE: {'content': source_text}}, 'settings': settings}
    started = time.perf_counter()
    proc = subprocess.run([str(SOLC), '--standard-json'], input=json.dumps(request),
                          text=True, capture_output=True, check=False)
    elapsed_ms = (time.perf_counter() - started) * 1000
    response = json.loads(proc.stdout)
    errors = [e for e in response.get('errors', []) if e['severity'] == 'error']
    diagnostics = '\n'.join(e['formattedMessage'] for e in response.get('errors', [])) + proc.stderr
    (OUT / f'stack-{name}.log').write_text(diagnostics or 'No compiler diagnostics.\n')
    result = {'pipeline': name, 'viaIR': via_ir, 'process_exit_code': proc.returncode,
              'success': proc.returncode == 0 and not errors,
              'compile_wall_ms': round(elapsed_ms, 3),
              'error_messages': [e['message'] for e in errors]}
    if result['success']:
        contract = response['contracts'][SOURCE]['StackPressure']['evm']
        result['initcode_bytes'] = len(contract['bytecode']['object']) // 2
        result['runtime_bytes'] = len(contract['deployedBytecode']['object']) // 2
    report['results'].append(result)
(OUT / 'stack-compile.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
if not report['results'][0]['success']:
    raise SystemExit('via-IR shape spike failed')
if not report['results'][1]['success'] and not any(
        'Stack too deep' in msg for msg in report['results'][1]['error_messages']):
    raise SystemExit('Legacy pipeline failed for an unexpected reason')
