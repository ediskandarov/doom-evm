# EVM Save/Load goal

Implementation authorized 2026-10-11; goal start 17:40:46 UTC.
Owner: Save/Load agent, `feat/save-load`, dedicated worktree
`/Users/eduard/sandbox/doom-evm-save-load`.
Baseline: fetched `origin/main` at `ff826659ceff0b3a5637e70109b62eb75a83d611`,
already contained by this clean branch. No main writes or Death/Respawn integration.

## Scope and retained discovery

Implement six original-style EVM save slots for Freedoom 0.13.0, Ultimate DOOM
Episode One, and DOOM II 1.9; save/load/overwrite/metadata/rejection, existing EVM
menu integration, exact restoration and focused native/EVM/browser proofs.
No audio, multiplayer, Relaxed Rendering, Solidity-default change or complete
historical acceptance. Stop after verified feature commits and handoff.

Discovery inspected `411e6049` and pinned C `a77dfb96cb91780ca334d0d4cfd86957558007e0`.
It found four authoritative roots (`GameState`, `UIState`, `InputRuntimeState`,
`EpisodeState`), explicit aliases reconstructed by DoomGame.load, and persistent
allocator history/render scratch. DSG1 and current-ring zone observations are
not complete restoration formats. Original C saves are lossy (RNG reset,
target/message clearing, short world coordinates, separate actor/special passes).
The proposed exact EVM continuation is an explicit archive/transaction adaptation,
not binary compatibility or equivalence to those original information losses.

Full Video/Options review at the new baseline: UIState now includes hideMessages;
MenuState owns Options preferences and SELECT LEVEL. Production display paths can
mutate rendering history without a gameplay tic. Current renderFrame still ticks;
load must use a separate control boundary. Immutable graphics/resource decodes
remain transient. Preserve existing schema, all allocator records/payloadExtent,
IDs/tombstones, array capacities, RNG, difficulty and rendering histories.

## Architecture gate

Measure actual initialized EVM state before selecting between typed slots,
ABI-byte slots, packed schema-bound slots and immutable code chunks. The discovery
preferred compact local slots provisionally. A storage-schema traversal is another
candidate: archive every word reachable from the four roots, without serializing
ephemeral GameContext/resources or unrelated transport/menu/resource storage.
Schema generated from pinned compiler storageLayout; no host gameplay injection.
No per-gameplay-tic snapshot copies. Compare size, save/restore gas, storage words,
memory high-water and wall time. Selection is complete: packed local slots. Actual authentic E1M1 archive859,296 bytes versus ABI5,639,104; fresh packed save584,309,294gas, overwrite129,653,992, restore123,304,814. Typed copies616,928,015/162,292,609/162,297,768; immutable chunks246,943,470/246,906,470/64,952,649. Immutable wins first-save and load cost; packed wins recurring overwrites and bounds retained slot storage instead of accumulating53 contracts per save. No full root decode on archive/restore. Pre-format measurement artifact retained; final production measurements remain pending.

## Shared interfaces and verification gates

This branch needs changes to Doom/Doom2 menu control boundaries and M_Menu; these
are authorized feature changes for later integrator reconciliation. Death/Respawn
owns its independent worktree. Avoid EpisodeRuntime/G_Ticker gameplay changes
where possible; any overlap must be documented, never independently merged.
Menu APIs must preserve Options, SELECT LEVEL, existing Frame/input protocols,
authenticated WAD identity and explicit browser profile3. Input/frame counters
must remain monotonic on load.

Gates: pinned-C save/menu investigation and focused source-preserving oracle;
schema coverage/round-trip/invalid/rollback Forge tests; affected Node input/menu/
release tests; actual isolated Anvil measurements and deterministic continuation
for movement/combat/movers/AI/projectiles/inventory/RNG/cross-map/repeated cycles;
real Chrome save/continue/load/continue/reload/game-switch/IWAD-isolation proof.
Reserved ports18880/8088 remain untouched. Track and stop only owned children.

Implementation checkpoint: codec and registry module verified; production/menu integration implemented but verification pending. Integration: feature branch only. Acceptance: pending.

Focused codec/registry tests:9 passed (3 inherited codec methods also execute in the registry subclass;6 distinct cases). Historical menu/Options/commercial navigation:13 unchanged tests passed. Pinned schema:133 nodes, identical root type graphs in Doom/Doom2. Native archive O0/O2/ASan+UBSan pass with declared align8 archive adaptation; pristine align4 LP64 UBSan failure is retained, not relabeled passed. Original six-slot native menu:25 frame checkpoints agree across3 profiles; EVM pixel comparison is pending.
All measured evidence and failures will be retained separately under
`artifacts/save-load/` (published metadata) and `artifacts/local/save-load/`
(ignored raw resources, frames and logs). No commercial assets in commits.
