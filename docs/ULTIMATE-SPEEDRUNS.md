# Separate Ultimate DOOM profile evaluation

Authorized extension requested during the Freedoom recording. Preserve the
Freedoom 0.13.0 profile, its resources, evidence and running Anvil. This experiment
uses separate `artifacts/local/ultimate-speedruns`, `artifacts/ultimate-speedruns`
and `tools/reference/ultimate_speedruns`; commercial WAD/resource payloads stay
ignored locally. No shared production adapters, gameplay algorithms or original
C are changed. The assigned feature branch/worktree remain unchanged.

Measured IWAD verification: supplied `artifacts/local/ultimate-doom/DOOM.WAD`,
12,408,292 bytes, MD5 `c4fe9fd920207691a9f493668e0a2083`, SHA-256
`6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`.
User identifies the source as Steam `base/DOOM.WAD`; this is the classic Ultimate
DOOM 1.9 identity, not the rerelease profile.

Select authentic single-player, non-TAS DSDA UV Speed recordings for E1M1–E1M9.
Preserve author, original archive/demo, URLs, exact commands and checksums. Start
with a native original-C replay, then independently verify remaining native
inputs and attempt EVM gameplay/full-rate rendering. Unsupported demo semantics
remain failures; no algorithms or goldens are altered to pass. A separately
hash-bound local resource adapter/profile is required because existing
`WadResources`/`EpisodeStartup` authenticate only Freedoom. Preserve those
production guards. Prefer checked-free dedicated port18641 for this profile;
never attach to the ongoing Freedoom18640 runtime or reserved ports.

Gates: exact classic IWAD and original command decoder; original-C exit and
cross-profile DSG1 equality; affected-root build; EVM startup/replay world
comparisons and actual Frame receipts; per-profile pixel/provenance distinctions;
35fps media if full capture succeeds. Proceed to remaining maps after the pilot; stop after available verified work or
concrete incompatibility, with reproducible evidence and no commercial bytes in
Git. This is separate experimental profile evaluation, not production IWAD
support or universal native equivalence.


## Integrated-baseline reset

The user's updated goal authorizes local gas, memory, RPC, timeout and checkpoint
limit changes with measured host monitoring; compiler/viaIR/optimizer/hardfork,
game rules, source fidelity, WAD identity and unknown-memory guards remain fixed.
Infrastructure failures do not authorize fabricated bytes or modified inputs.

New worktree `/private/tmp/doom-evm-ultimate-speedruns`, branch
`feat/ultimate-episode-speedruns`, baseline
`51e879247bb3d6d809af8a0516a097f71c3d0756` from fetched origin/main. Confirmed
integrated `DoomMenu`, `Z_ZoneVirtual` and `EpisodeRuntime`, with preserved
integration evidence. Five absent speedrun-only commits were cherry-picked;
no integrated menu/virtual-memory commit was duplicated. Main and other owners'
worktrees were not modified. The old worktree remains recovery evidence.

The old Freedoom E1M2 run captured250/1942 frames and251 exact world snapshots
before Node's512MiB string limit stopped a chain checkpoint. Its ten-tic
checkpoint, failed attempts, receipts and all native outputs remain local.
Owned old native workers were stopped for reset; its Anvil had already stopped
in the runner's failure cleanup. Completed raw native state streams are being
losslessly compressed with round-trip byte/hash checks to preserve them while
relieving local disk pressure; no original fixtures or goldens are removed.

Commercial-profile canonical world streams, frame pixels, resources and MP4s
remain local because world snapshots contain map geometry. Commit metadata,
source identities, counts and hashes only; never commercial payloads or artwork.
