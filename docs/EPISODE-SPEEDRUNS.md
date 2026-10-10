# Episode One full-rate speedrun experiment

Measured start: 2026-10-10 19:24:36 UTC. Owner: this goal's primary agent.
Worktree: `/Users/eduard/sandbox/doom-evm-speedruns-vptr`; branch:
`feat/episode-speedruns-vptr`; baseline: `6fb54ce443399ec661ea3c0d64e23aacc15d98e0`.

Scope: authentic downloadable E1M2–E1M9 demos, pinned-original-C verification,
exact ticcmd EVM replay, every post-tic EVM frame, experimental virtual-pointer
provenance, resumable independent recordings, per-map reports/manifests and an
episode summary. E1M1's existing accepted evidence is inherited, not rerun by
default. Own new `tools/reference/episode_speedruns`, `src/support/EpisodeSpeedrun*`,
`artifacts/episode-speedruns` and this report. Preserve existing runners and engine
sources. No main edits, merges, pushes, allocator changes or memory-budget changes.

Dependencies: initialize the pinned original DOOM submodule; link `.toolchain` to
`../doom-evm/.toolchain` read-only; source `scripts/env.sh`; regenerate missing
pinned IWAD/resources in this worktree's ignored `artifacts/local`; build native
oracles as needed. Prefer checked-free Anvil port 18640; refuse occupied/reserved
ports and stop only the owned child. Generated MP4s remain ignored under
`artifacts/local/episode-speedruns/E1Mx`.

Gates: preserve author/source/original tape/hash; prove decoder and native
compatibility/exit before EVM replay; compare every DSG1 observation; retain mined
Frame receipts and every provenance sample; distinguish declared native-profile
equality from virtual-derived pixels; independently verify 35 Hz complete media,
source/compiler/ABI/resource identity and checkpoint integrity. Failures retain
precise evidence and do not invalidate other maps. Inspect the startup call path
before attributing E1M7 MemoryOOG to size; request existing narrowly scoped fix
integration if needed, without copying it or merging another feature branch.

Stop after available verified recordings or concrete per-map acquisition,
compatibility or execution blockers are documented. No later engine goals or full
Phase 4 acceptance. Record actual timing and available usage only.
