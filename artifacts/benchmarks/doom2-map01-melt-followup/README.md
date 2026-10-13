# Integrated Melt Wipe focused gameplay follow-up

This runner derives from the immutable historical `../doom2-map01-performance/run.mjs`
at c4905b3. It retains the 50-frame route, three warmup gameplay tics, genuine mined
transactions, production receipt waiter, CPU sampling, source authentication and
browser installer. Only direct mode is used for the integration comparison.

`--enable-wipe-in-direct` enables the same contract opt-in used by the production
browser and drains startup presentation transactions before warmup/measurement.
`--web-root` serves a goal-owned copy of the shipped website, excluding existing
local config/palette files; the main browser configuration stays intact. Source
and package authentication still uses the integrated main tree.

Continuation receipts are retained separately in `presentation`; they are excluded
from the steady gameplay denominator. Every ordinary packet reads the authoritative
input sequence before timing in both comparison arms. This extra untimed read is an
explicit harness adaptation. CPU windows include setup/warmup and any wipe steps.

One sequential 50-frame direct run per arm, same newly compiled source/resources,
one opt-out and one opt-in, is a focused check, not a repetition of the original
three-run browser/direct campaign or a statistically controlled regression study.
World/status-bar hashes are recorded separately to identify any pixel differences.
Use the historical analyzer separately on each output. Keep the original dataset
and report unchanged. No commercial pixels or IWADs are published.

Reproduction commands and actual observations are in
`docs/INTEGRATION-BENCHMARK-MELT-WIPE.md`.
