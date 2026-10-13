#!/usr/bin/env python3
"""Independent statistics, evidence, payload and report-link checks; no EVM work."""
import csv, hashlib, json, math, pathlib, re, statistics, subprocess
ROOT=pathlib.Path(__file__).resolve().parents[3]
BASE=ROOT/'artifacts/benchmarks/doom2-map01-performance'
PRIMARY=BASE/'results/primary'
manifest=json.loads((PRIMARY/'manifest.json').read_text())
summary=json.loads((PRIMARY/'summary.json').read_text())
def close(actual,expected): assert math.isclose(actual,expected,rel_tol=1e-10,abs_tol=1e-6),(actual,expected)
for mode in ('browser','direct'):
    durations=[]; transactions=[]; intervals=[]
    for entry in [r for r in manifest['runs'] if r['mode']==mode]:
        run=json.loads((PRIMARY/entry['file']).read_text())
        rows=[r for r in run['transactions'] if r['phase']=='measure']; assert len(rows)==50
        assert all(r['status']=='0x1' for r in rows)
        assert len({r['hash'] for r in rows})==len({r['frameId'] for r in rows})==50
        start=rows[0]['tick']['inputDispatchMs'] if mode=='browser' else rows[0]['submissionMs']
        end=max(rows[-1]['frame']['canvasEndMs'],rows[-1]['tick']['tickEndMs']) if mode=='browser' else rows[-1]['completionMs']
        durations.append(end-start);transactions.extend(rows)
        stamps=[r['frame']['canvasEndMs'] if mode=='browser' else r['receiptMs'] for r in rows]
        intervals.extend(b-a for a,b in zip(stamps,stamps[1:]))
        assert "drawing from 'AC Power'" in run['powerBefore'] and "drawing from 'AC Power'" in run['powerAfter']
    actual=summary['aggregate'][mode]; close(actual['elapsedMs'],sum(durations));close(actual['gameplayFPS'],len(transactions)*1000/sum(durations));close(actual['transactionsPerSecond'],actual['gameplayFPS'])
    close(actual['frameIntervalsMs']['mean'],statistics.mean(intervals));close(actual['frameIntervalsMs']['median'],statistics.median(intervals));close(actual['frameIntervalsMs']['p95'],statistics.quantiles(intervals,n=100,method='inclusive')[94])
    for key,values in [('gasPerFrame',[r['gasUsed'] for r in transactions]),('transactionReceiptLatencyMs',[r['receiptMs']-r['submissionMs'] for r in transactions])]:
        close(actual[key]['mean'],statistics.mean(values));close(actual[key]['median'],statistics.median(values));close(actual[key]['p95'],statistics.quantiles(values,n=100,method='inclusive')[94])
    if mode=='browser':
        values=[r['frame']['canvasEndMs']-r['tick']['inputDispatchMs'] for r in transactions];close(actual['inputToCanvasMs']['median'],statistics.median(values));close(actual['inputToCanvasMs']['p95'],statistics.quantiles(values,n=100,method='inclusive')[94])
for sums in (PRIMARY/'SHA256SUMS',BASE/'results/ac/SHA256SUMS'):
    for line in sums.read_text().splitlines():
        digest,name=line.split('  ',1);assert hashlib.sha256((sums.parent/name).read_bytes()).hexdigest()==digest,name
csv_rows=list(csv.DictReader((PRIMARY/'frames.csv').open()));assert len(csv_rows)==336
assert sum(r['phase']=='measure' for r in csv_rows)==300
for p in (BASE/'results').rglob('*.json'):
    source=p.read_text();json.loads(source)
    assert '"rgbHex"' not in source,p
    for field in ('"pixels":','"rgb":','"logs":','"bytecode":','"runtime": "0x','"privateKey":','"mnemonic":','"serial_number":','"platform_UUID":'):
        assert field not in source,(p,field)
for p in BASE.rglob('*'):
    assert p.suffix.lower() not in ('.wad','.png','.indexed8','.bin'),p
report=ROOT/'docs/benchmarks/DOOM2-MAP01-PERFORMANCE.md'
for target in re.findall(r'\]\(([^)]+)\)',report.read_text()):
    if '://' not in target: assert (report.parent/target.split('#')[0]).exists(),target
for p in BASE.glob('*.mjs'):subprocess.run(['node','--check',str(p)],check=True,capture_output=True)
subprocess.run(['git','diff','--check'],cwd=ROOT,check=True)
print('PASS independent count/time/percentile calculations, 300 primary measured rows, evidence hashes, JSON/payload scope, report links, JS syntax and formatting')
