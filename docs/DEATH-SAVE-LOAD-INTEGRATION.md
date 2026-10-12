# Death/Respawn and Exact EVM Save/Load integration

Both completed features are integrated and focused combined verification passes.
The approved product is **six-slot Exact EVM Save/Load for user convenience,
explicitly noncanonical**. The original-style menus execute in EVM. The canonical
research is preserved as evidence of this intentional deviation; its proposed
semantic archive/lifecycle architecture was **not selected or implemented**.

## History and shared-state review

Clean fetched baseline: `ff826659ceff0b3a5637e70109b62eb75a83d611`.
Death/Respawn was merged first, preserving `3b3fd156`, `14251b6e` and the final
`b1527763e8b37309c12d083e4db342fd47f8f5e3`. Its normal merge is
`3999675710548c420cca76c855eba67a1fe21caf`. The user paused integration and asked
that the first uncommitted Save/Load merge be discarded; it was aborted without
rewriting Death/Respawn or either feature branch.

The corrected Save/Load tip is `028466fb2f253a2bd53fbc41d486d3a84b1557e6`,
descending from implementation checkpoints `d3c33c47`, `8e19aced` and
`01b09cdbc31e774b7da9937f3a9c67b3ad3d958b`. The intervening commit adds exactly
eight research/report files; production, tests, compiler settings and earlier
Save/Load evidence are unchanged. Its normal merge after Death/Respawn is
`359020c5a8d074271331abe7a55ed77562010192`. Focused integration tests/tools were
committed as `ae6ae6f63f1652dc200a78bcf69ef945b220f821`.

Solidity adapter edits merged without textual conflicts. Review confirms the
source Death/Respawn callback and queued-reborn menu path coexist with the
source Save/Load control branch. Ordinary menu packets still dispatch original
G_Ticker rebirth before its world freeze. Exact save/load transactions run before
EpisodeRuntime.tick: load restores a snapshot and publishes cached EVM output
without a game tic. A queued rebirth **in the restored snapshot** is serviced by
the next ordinary/menu tic. This control boundary is an intentional extension,
not canonical G_SaveGame/G_LoadGame action timing or lossy C save-file behavior.

The unchanged133-node compiler-derived archive covers GameState, UIState,
InputRuntimeState and EpisodeState, including player/actor references, thinker
ordering/capacity/tombstones, allocator/cache ownership/history, both RNG streams,
difficulty history and renderer/UI state. DeathFlow/EpisodeAux callbacks are
transient and excluded. DoomGame.load rebinds context aliases/resources/hooks.
Menu navigation, transport counters, WAD deployment bindings and the six-slot
registry are separate. Load synchronizes supported Options to saved UI state;
input sequence/frame identifiers remain monotonic while simulation clocks rewind.

Four generated browser release files conflicted. Both contract artifacts and
pins were regenerated from the combined build, checking all metadata source hashes,
method selectors and immutable references. Runtime sizes: Doom927,930 bytes;
Doom2 905,156. No integration-specific production Solidity, original C,
compiler/budget, existing test or golden changes were needed.

The Death agent's separate AGENTS.md cache guide is preserved verbatim: copy both
cache/output into owned directories, retain pinned settings, let Forge validate
source dependencies/rebuild changes, and verify release metadata. It neither
allows stale artifacts nor reduces acceptance requirements. The affected85-file
build took245.30 seconds; its resumed warm validation skipped compilation.
The focused33-test run took491.32 seconds including changed-probe compilation.
The observation-only memory build compiled81 files in131.61 seconds. Forge JSON
output did not separately expose the focused compiler file count; none is inferred.

## Fresh combined-main verification

[Published checkpoint](../artifacts/phase4/death-save-main/integration.json)
binds the source/history/release identity and fresh results separately from
source-agent acceptance. All commands retain the pinned compiler/viaIR/optimizer,
Cancun, normal10B-gas/1GiB-memory Anvil budget and isolated runtime ownership.
Long multi-tic Forge tests use the source-approved200B aggregate test allowance;
individual real transactions retain10B.

- **33 Forge executions pass:**25 source save/archive/menu/Options/commercial
  cases, four source death/rebirth cases and four new combined cases. The latter
  test save→genuine monster death→load, save→death→same-map UV rebirth→load,
  dead/corpse and queued-reborn snapshots, full-root/zone-history continuation,
  all six slots/overwrite and invalid/incompatible atomic rollback. Existing
  nested root/reference/capacity/grow-shrink/digest/schema guards remain intact.
- **80 Node tests pass:**keyboard/F2/F3, input sequencing/transaction locking,
  menu/Options, profile/resource authentication, installation/recovery/reset
  guards and source-mapped memory instrumentation.
- **Original C:**fresh O0/O2/ASan+UBSan builds reproduce276 canonical golden world
  comparisons and51 complete framebuffer/palette comparisons (92 worlds and17
  distinct frame pairs repeated across profiles), without changing fixtures.
- **Three-game real Chrome/Anvil:**Freedoom/Ultimate E1M1 and DOOM II MAP07 at UV
  save an active world, die through actual movement/rockets/monsters, load alive,
  replay the same inputs with identical complete root digests and following
  output, rebirth on the original map/skill, load earlier live/dead snapshots,
  and retain all six compatible independent slots. Original IDFA supplies the
  accepted inventory route; no state/pixel injection or test probe is in browser
  gameplay. Original Options, Select Level and cross-map loads are also exercised.
- **Native/combined browser:**27 fresh case/profile executions compare3,411
  gameplay-tic observations and61,398 field-family comparisons, including player,
  actor, camera, inventory, map/skill, face and RNG. All126 complete frame/palette
  comparisons pass; these cover27 unique EVM receipt checkpoints across the
  original/replayed/reborn branches and compiler profiles. Production browser
  getters expose18 field families, not the entire native canonical world.
  Complete native world coverage above comes from the unchanged Forge goldens;
  whole EVM save/continuation coverage additionally uses all four-root digests.
- **Reload supplement:**all three installations/slot metadata survive browser
  reload and switching on the same running chain, with no resource redeployment.
  Original Load restores cached output and saved player view; original resave
  proves identical whole-root digest; real held input moves the player afterward.
  Source Solidity default2 and actual explicit browser initializer3 are verified.
- **Output/rollback:**338 primary and59 supplemental Canvas checkpoints compare
  every pixel with their real Frame/FramePalette receipts (397 total transport
  checks).18 mined failed Save/Load transactions preserve complete contract
  storage roots and emit no logs. Forge adds corrupt/incompatible/invalid-save
  and rebirth-related failure checks. No gameplay advances merely to load output.

The primary browser run completed all three combined-state cases but its **overall
pass=false is preserved**: the final helper sent F3 under an already open main
menu, where original M_Responder ignores that shortcut. The following Enter went
to Select Level. The separate successful reload gate closes the main menu and
asserts screen5 before loading. Two supplemental setup failures are retained:
its keyboard loop was still stopped, then its expected image was older than the
loop's new EVM frame. Explicit source-style loop startup and a fresh ordinary
frame resolve those helper issues. Actual held input replaces a within-packet
press/release for movement. No production pixels, expected golden or assertion
was relaxed. The wrong-menu frame still passed Canvas/receipt transport equality;
it is not counted as a successful load. An earlier superseded fresh-native setup
was canceled using only proven owned processes. See [attempts](../artifacts/phase4/death-save-main/attempts.json).

The accepted primary window was05:20:24.612–05:33:15.866UTC on2026-10-12;
its failed reload boundary is included. The successful bounded reload window was
05:48:46.999–05:55:40.477UTC. The source instruction pause and prior attempts are
recorded separately; these are measured run windows, not a continuous timing
claim or billing estimate. The goal service remained paused after the explicit
hold; its available earlier counter was117,706 tokens/242 seconds at that pause.
No missing active-work or model-specific cost attribution is estimated.

## Measured costs and storage limits

Fresh ordinary production Chrome measurements include save/load and cached output
emission, excluding earlier menu-navigation packets. They cover initial first-map
samples, active/dead/reborn worlds and cross-map restoration, not all maps/history.

| Game / measured maps | Payload bytes | Fresh save gas | Overwrite gas | Load gas |
|---|---:|---:|---:|---:|
| Freedoom E1M1 |928,064|654,276,471–662,468,700|156,657,544–169,445,834|141,424,476–192,713,437|
| Ultimate E1M1 |461,888|312,234,745–318,748,660|78,468,316–91,487,260|70,339,627–92,905,879|
| DOOM II MAP01/MAP07 |347,072–406,560|245,281,242–296,531,630|68,176,611–81,942,110|52,485,884–83,756,662|

Separate fresh Freedoom production/memory evidence uses an unmodified deployment,
observer-only clone and source-mapped equal-cost GAS→MSIZE clone. Full state/root
and Frame/palette outputs match; the two observer versions have identical gas.

| Operation | Unmodified production gas | Call-frame MSIZE boundary | RPC/mining seconds |
|---|---:|---:|---:|
| Save |654,019,922|2,324,992 bytes|0.108924|
| Load |146,140,569|1,858,848 bytes|0.133696|
| Overwrite |156,363,532|2,324,992 bytes|0.128510|

The memory boundary follows production save/load and Frame encoding, before the
observer encoding; separate SHA-256 frames and host RSS are excluded. Commercial
memory maxima are inherited/source-scoped, not freshly inferred from Freedoom.
The Freedoom payload has29,002 words plus eight slot-header words per occupied
slot. Archives cap at262,144 words/8MiB; six maximum payloads would be48MiB plus
headers, a projection. Restore can leave unreachable old storage tails; logical
exactness is verified, storage compaction/trie disk use is not. Large-map and
long-history costs/10B-gas ceilings remain performance limits. These measured
transactions require the project's high-gas development EVM.

## Preservation, fidelity and remaining limits

The94 nonoverlapping source files/reports are byte-identical to their tips;
16 protected gameplay/memory/input/browser/rendering boundaries match the prior
main. Both final feature worktrees remain clean at their handoff tips. Original C
is unchanged at `a77dfb96cb91780ca334d0d4cfd86957558007e0`. All27 recorded historical
MP4 paths retain bytes, timestamps and hashes; no recording was generated/deleted.
Raw commercial resources/images/receipts stay ignored under goal-local artifacts.
No WAD, MP4 or new extracted commercial asset is committed. The source Freedoom
license's original BOM/CRLF bytes are preserved; formatting checks exclude that
unchanged license. One whitespace-only line in new memory tooling was removed
later, with the exact executed runner archived separately; no costly rerun is
needed for that nonsemantic correction.

Native compatibility remains **RESTRICT** to the declared LP64, initialized-zone,
borrowed-UI/compiler/display profiles. Finite native-equal final pixels do not
establish universal native-address equivalence. Virtual pointer provenance and
all memory policies/unknown-byte guards remain unchanged; profile3 is explicit,
Solidity defaults remain2, and Relaxed Rendering is absent. The historical mixed
STTMINUS allocation diagnosis, corrected borrowed-UI evidence and two Full Video
virtual-derived exceptions keep their original classifications.

Source-agent evidence is inherited: Death89 Forge/44 Node/six real browser cycles;
Save25 Forge/67 Node/five580-row native/EVM scenarios and three-game browser proof;
canonical research99 native runs. Those are not relabeled newly rerun acceptance.
Saves are contract/engine/schema/IWAD/profile-bound, with no binary C compatibility,
engine migration or cross-contract import. A fresh Anvil reset loses saves without
an explicit backup; installation journals do not back up gameplay storage.

Full inherited Phase0–4 acceptance, all nine full video rerenders and both full
DOOM II speedrun reruns remain deferred. Canonical Save/Load implementation is
unselected. Palette-effects/visual-gap recommendations, sound/music/multiplayer,
unsupported smaller/Low Detail/mouse/F11 options and MAP30 cast remain outside
this goal. Existing G_WorldDone/subsequent-startup standalone-video and production
browser melt limitations are unchanged. No additional goal starts automatically.

[Death report](DEATH-RESPAWN.md), [Exact Snapshot report](SAVE-LOAD.md),
[canonical research](SAVE-LOAD-CANONICAL-DISCOVERY.md),
[focused reproduction](../tools/reference/death_save/README.md).
