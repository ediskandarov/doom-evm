#!/usr/bin/env python3
"""Bind Goal4.1's executed focused gates and new mapping; never rewrite history.

Reads only source, named verification output, and finite numeric fixture metadata.
No session log/transcript access. --check validates committed evidence in place.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASELINE = 'b16c2a4'
EVIDENCE = ROOT / 'artifacts/phase4/video-verification.json'
MAPPING = ROOT / 'artifacts/phase4/video-source-map.json'

def sha(b): return hashlib.sha256(b).hexdigest()
def digest(p): return sha((ROOT / p).read_bytes())
def git(*args): return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()

def preserve():
    baseline = git('rev-parse', BASELINE)
    paths = ['src', 'test', 'web', 'original', 'tools/usage', 'artifacts/usage',
             'artifacts/phase0', 'artifacts/phase1', 'artifacts/phase2', 'artifacts/phase3',
             'foundry.toml', 'execution-budget.json', 'docs/PHASE3-PLAN.md',
             'docs/PHASE3-FEATURE-MATRIX.md', 'docs/PHASE3-REPORT.md',
             'docs/DRAWBOUNDS-BLOOD-CRASH.md']
    changes = git('diff', '--name-status', baseline, '--', *paths).splitlines()
    allowed = {'src/doom/v_video.sol', 'src/doom/v_video_types.sol', 'src/support/VideoProbe.sol',
               'test/unit/v_video.t.sol', 'test/integration/VideoPrimitives.t.sol'}
    for row in changes:
        kind, name = row.split('\t', 1)
        assert kind == 'A' and (name in allowed or name.startswith('test/fixtures/phase4_video/')), row
    assert git('-C', 'original/DOOM', 'rev-parse', 'HEAD') == 'a77dfb96cb91780ca334d0d4cfd86957558007e0'
    return {'baselineRevision': baseline, 'allExistingProtectedSourcesTestsAndEvidenceUnchanged': True,
            'acceptedCertificate': {'path': 'artifacts/phase3/acceptance.json',
                                    'sha256': digest('artifacts/phase3/acceptance.json')},
            'postAcceptanceCompatibility': {'path': 'artifacts/phase3/drawbounds-compatibility.json',
                                           'sha256': digest('artifacts/phase3/drawbounds-compatibility.json')},
            'auditWorktree': 'Not inspected or modified; no dependency on independent memory audit.'}

def build_mapping():
    spec = importlib.util.spec_from_file_location('compat_spans', ROOT / 'tools/audit/compatibility.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    ports = module.spans('src/doom/v_video.sol')
    native = json.loads((ROOT / 'test/fixtures/phase4_video/native.json').read_text())
    names = ['V_Init', 'V_MarkRect', 'V_CopyRect', 'V_DrawPatch', 'V_DrawPatchFlipped',
             'V_DrawPatchDirect', 'V_DrawBlock', 'V_GetBlock']
    bindings = []
    for name in names:
        original = next(r for r in native['functionMapping'] if r['function'] == name)
        bindings.append({'function': name, 'original': original, 'port': ports[name],
                         'verificationScope': 'Bounded native RANGECHECK fixtures; not exhaustive branch/invalid-memory equivalence.'})
    source_paths = ['src/doom/v_video.sol', 'src/doom/v_video_types.sol', 'src/support/VideoProbe.sol',
                    'src/doom/r_draw.sol', 'src/doom/r_state.sol', 'src/doom/m_bbox.sol',
                    'src/doom/r_data.sol', 'src/evm/FrameProtocol.sol', 'src/evm/ResourceStore.sol',
                    'test/unit/v_video.t.sol', 'test/integration/VideoPrimitives.t.sol',
                    'tools/reference/video/checkpoint.py', 'tools/reference/video/evm.mjs',
                    'tools/reference/video/reference.py', 'tools/reference/video/compat.h',
                    'tools/reference/video/host.c', 'foundry.toml', 'execution-budget.json',
                    'web/protocol.mjs']
    return {'schemaVersion': 1, 'goal': '4.1', 'kind': 'separate-phase4-video-source-binding',
            'pass': True, 'historicalAcceptance': preserve(),
            'upstreamCommit': native['upstreamCommit'], 'functionBindings': bindings,
            'sourceSha256': {p: digest(p) for p in source_paths},
            'headerBinding': {'original': 'original/DOOM/linuxdoom-1.10/v_video.h',
                              'port': 'src/doom/v_video_types.sol',
                              'globals': ['screens[5]', 'dirtybox[4]'],
                              'deferred': ['gammatable[5][256]', 'usegamma']},
            'context': 'Memory-only VideoState; screen0 aliases existing indexed8 framebuffer; no production engine/Frame/storage schema change.',
            'newHelpers': {k: v for k, v in ports.items() if k not in names}}

def log_gate(path, command, count):
    raw = (ROOT / path).read_text()
    summaries = re.findall(r'Ran \d+ test suites? in .*?: (\d+) tests? passed, (\d+) failed, (\d+) skipped', raw)
    assert summaries and tuple(map(int, summaries[-1])) == (count, 0, 0), (path, summaries)
    assert '[FAIL' not in raw, path
    passed = re.findall(r'^\[PASS\] (.+?)(?: \(gas:| \(runs:)', raw, re.M)
    assert len(passed) == count, (path, passed)
    return {'pass': True, 'command': command, 'tests': count, 'testNames': passed,
            'logPath': path, 'logSha256': digest(path),
            'reportedCompileSeconds': [float(x) for x in re.findall(r'Solc [\d.]+ finished in ([\d.]+)s', raw)],
            'logsAvailability': 'Ignored local output; compact test names/counts/source bindings are committed.'}

def build():
    mapping = build_mapping()
    native_path = 'test/fixtures/phase4_video/native.json'
    native = json.loads((ROOT / native_path).read_text())
    assert native['exactAgreement'] and native['caseCount'] == 58 and len(native['profiles']) == 3
    for p, h in native['sourceSha256'].items(): assert digest(p) == h, p
    cases = json.loads((ROOT / 'test/fixtures/phase4_video/cases.json').read_text())
    assert digest('test/fixtures/phase4_video/cases.bin') == cases['casesSha256']
    patches = json.loads((ROOT / 'test/fixtures/phase4_video/patches.json').read_text())
    for p in patches['patches']: assert digest('test/fixtures/phase4_video/' + p['path']) == p['sha256']
    evm_path = 'artifacts/phase4/video-evm.json'; evm = json.loads((ROOT / evm_path).read_text())
    assert evm['pass'] and len(evm['rows']) == 7 and evm['rollback']['counterUnchanged']
    assert all(r['status'] == '0x1' for r in evm['rows']) and evm['rollback']['status'] == '0x0'
    for p, h in evm['sourceSha256'].items(): assert digest(p) == h, p
    gates = {
        'focused': log_gate('artifacts/local/video/final-focused.log',
            ".toolchain/bin/forge test --match-path 'test/{unit/v_video,integration/VideoPrimitives}.t.sol' --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv",17),
        'dependencies': log_gate('artifacts/local/video/dependencies.log',
            ".toolchain/bin/forge test --match-path 'test/{unit/{m_bbox,r_draw,z_zone_backing,z_zone_initialization,WadResources},integration/FrameEvent}.t.sol' --skip Doom --skip GameplayProbe --skip RendererProbe --skip WadResourcesProbe -vv",33),
        'legacyWorld': log_gate('artifacts/local/video/legacy-world.log',
            '.toolchain/bin/forge test --match-path test/integration/DoomRenderer.t.sol --match-test testFullNativeAngle0 -vv',1),
        'native': {'pass':True,'command':'python3 tools/reference/video/reference.py --check',
                   'profiles':3,'cases':58,'successfulCases':48,'rangeErrorCases':10,
                   'scope':'Successful Solidity cases compare all five buffers, dirtybox and GetBlock digests; error cases compare original rejection/control behavior.',
                   'proof':{'path':native_path,'sha256':digest(native_path)}},
        'ordinaryEVM': {'pass':True,'command':'node tools/reference/video/evm.mjs',
                        'frames':7,'completePixelComparisons':448000,
                        'originalCPatchFrames':6,'originalCPixelComparisons':384000,
                        'proof':{'path':evm_path,'sha256':digest(evm_path)}},
        'formatAndIntegrity': {'pass':True,'commands':[
            '.toolchain/bin/forge fmt --check src/doom/v_video.sol src/doom/v_video_types.sol src/support/VideoProbe.sol test/unit/v_video.t.sol test/integration/VideoPrimitives.t.sol',
            'git diff --check','node --check tools/reference/video/evm.mjs',
            'python3 tools/reference/video/checkpoint.py --check']}
    }
    return mapping, {'schemaVersion':1,'goal':'4.1','pass':True,'status':'complete verified goal, not final Phase4 acceptance',
        'start':'2026-10-10T07:54:16Z','structuredGoalCreatedAt':1791618856,
        'implementationCommit':git('rev-parse','498081b'),
        'agents':[{'name':'/root','ownership':'Solidity/interfaces/tests/integration/ledger'},
                  {'name':'/root/video_native','ownership':'Native oracle and fixtures',
                   'status':'completed','model':'Inherited; specific runtime model identifier not exposed'}],
        'usage':'Actual structured goal closure counter recorded separately; never added to input/cached/output/reasoning counts. No raw sessions ingested.',
        'historicalAcceptance':mapping['historicalAcceptance'],'gates':gates,
        'sourceMapSha256':sha((json.dumps(mapping,indent=2)+'\n').encode()),
        'measuredGas':{'scope':'Support-probe total transactions including pattern construction/resource reads/Frame, not production DOOM costs or isolated drawing-loop cost.',
                       'deployment':evm['deploymentGas'],'renderMinimum':min(r['gasUsed'] for r in evm['rows']),
                       'renderMaximum':max(r['gasUsed'] for r in evm['rows']),'budget':evm['gasBudget']},
        'deferred':['Full inherited Phase0–3 suite until final Phase4 acceptance',
                    'Real browser UI/transport acceptance until feature integration',
                    'Status bar/HUD/automap/intermission/palette and all later goals'],
        'resolvedHarnessFailures':['Unused patchId=-1 incorrectly selected fixture filename; fixed loader only.',
                                   'Integration expectation treated negative face offsets as unsigned; fixed expectation only.',
                                   'Anvil mutually exclusive disable-block-gas-limit and gas-limit flags; use explicit configurable10B block/transaction budget.'],
        'risks':['Finite well-formed IWAD/RANGECHECK comparison domain; no arbitrary malformed-WAD native equivalence.',
                 'Four screen arrays preserve logical layout, not contiguous C pointers.',
                 'No production UI consumer or cross-transaction screen persistence integrated yet.',
                 'Gamma/palette event design belongs to Goal4.2; independent audit remains separate.'],
        'stop':'Do not proceed beyond Goal4.1. Goal4.2 starts at st_lib widgets, screen4 backing and explicit legacy/fullscreen vs168-row mode.'}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    if args.check:
        # Portable integrity check requires no ignored logs; executed numeric proof remains frozen.
        evidence=json.loads(EVIDENCE.read_text());mapping=build_mapping()
        expected={'focused','dependencies','legacyWorld','native','ordinaryEVM','formatAndIntegrity'}
        assert set(evidence['gates'])==expected,'missing or unexpected gate'
        assert evidence['pass'] and all(v['pass'] for v in evidence['gates'].values())
        for name,count in [('focused',17),('dependencies',33),('legacyWorld',1)]:
            gate=evidence['gates'][name];assert gate['tests']==count and len(gate['testNames'])==count
        native=json.loads((ROOT/'test/fixtures/phase4_video/native.json').read_text())
        assert native['exactAgreement'] and native['caseCount']==58 and len(native['profiles'])==3
        for p,h in native['sourceSha256'].items():assert digest(p)==h,p
        cases=json.loads((ROOT/'test/fixtures/phase4_video/cases.json').read_text())
        assert cases['caseCount']==58 and digest('test/fixtures/phase4_video/cases.bin')==cases['casesSha256']
        patches=json.loads((ROOT/'test/fixtures/phase4_video/patches.json').read_text())
        assert len(patches['patches'])==7
        for p in patches['patches']:assert digest('test/fixtures/phase4_video/'+p['path'])==p['sha256']
        assert MAPPING.read_text()==json.dumps(mapping,indent=2)+'\n','stale source mapping'
        assert digest('artifacts/phase4/video-source-map.json')==evidence['sourceMapSha256']
        for gate in evidence['gates'].values():
            if 'proof' in gate: assert digest(gate['proof']['path'])==gate['proof']['sha256']
        evm=json.loads((ROOT/'artifacts/phase4/video-evm.json').read_text())
        assert evm['pass'] and len(evm['rows'])==7 and all(r['status']=='0x1' for r in evm['rows'])
        assert evm['rollback']['status']=='0x0' and evm['rollback']['logs']==0 and evm['rollback']['counterUnchanged']
        for p,h in evm['sourceSha256'].items():assert digest(p)==h,p
    else:
        mapping,evidence=build();MAPPING.write_text(json.dumps(mapping,indent=2)+'\n');EVIDENCE.write_text(json.dumps(evidence,indent=2)+'\n')
    print(json.dumps({'pass':True,'goal':'4.1','sourceFunctions':8,'verification':str(EVIDENCE.relative_to(ROOT))}))
if __name__=='__main__':main()
