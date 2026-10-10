# Episode startup oracle fixtures

Comparison-only outputs of pinned original DOOM C at
`a77dfb96cb91780ca334d0d4cfd86957558007e0`, using Freedoom 0.13.0 Phase 1 IWAD
SHA256 `7323bcc168c5a45ff10749b339960e98314740a734c30d4b9f3337001f9e703d`.
Original engine source retains GPL-2.0-only provenance. Embedded original WAD
bytes (including REJECT) and asset-derived observations retain Freedoom's
BSD-3-Clause provenance; its unchanged license is included as COPYING.txt.

The manifest records original source hashes/spans, adaptations, compiler/profile,
observer hashes and every binary digest. Files encode active-player/live-world
DSG1, supplementary collision/grouping/start/scroller state, normalized live zone
headers and owners, startup flow globals and mutable difficulty values.

Reproduce with `python3 tools/reference/episode_startup/reference.py --check`.
These files are expected results only. Production initialization receives
original authenticated resources; no fixture/world/allocation tape is injected.
See ../../../../docs/PHASE4-EPISODE-STARTUP.md for coverage and finite-domain limits.
