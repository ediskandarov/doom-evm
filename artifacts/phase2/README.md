# Phase 2 acceptance evidence

`final-verification/` is an unmodified copy of the complete successful run of
`python3 scripts/verify-phase2.py` at commit
`82e24e1c3f742a528dbbd63bdfb16e2d0d585774`.

- [Summary and source identities](final-verification/summary.json)
- [All 196 Solidity tests](final-verification/foundry-tests.log)
- [Inherited Phase 0](final-verification/inherited-phase0/summary.json) and [Phase 1](final-verification/inherited-phase1/summary.json)
- [Ordinary full-renderer report](final-verification/renderer.json)
- [Browser report](final-verification/renderer.browser.json) and [screenshot](final-verification/renderer.browser.png)
- [Eight full views and wall-only view](final-verification/renderer.frames/), including actual pixels, native-bound metadata, exact diffs and PNGs
- [Production, browser, rejection and wall receipts](final-verification/renderer.receipts/)
- [Drawing](final-verification/draw-measurements.json), [resource access](final-verification/resource-measurements.json), [authenticated source](final-verification/source-measurements.json), [walls](final-verification/wall-measurements.json)
- [Final source/documentation audit](final-audit.json) and [archive hashes](manifest.json)

Absolute/local paths inside the raw reports record where execution happened.
Their copies here retain the same relative filenames and original bytes; paths
were not rewritten. The archive manifest hashes every evidence file.

After the run, only README, PORTING and the three named specification/plan/report
Markdown documents were reconciled. The final audit compares all guarded inputs
and the original submodule with the passing snapshot, rejects any other change,
and records the new documentation hashes. No implementation, fixture, test,
verification tool, schema or compiler setting changed after acceptance.

The short static run is not a sustained FPS or long-running memory claim.
The full-view MSIZE measurements are actual checkpoints in the separate probe,
not an exact production peak. See the [acceptance report](../../docs/PHASE2-REPORT.md)
for scope and deviations.

Rendered images derive from Freedoom; copyright belongs to the Freedoom
contributors, under the [preserved BSD license](../../test/fixtures/wad/COPYING.txt).
No proprietary WAD is included.
