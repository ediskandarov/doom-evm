# Phase 4 Goal 4.0a — Independent memory architecture review

**Decision: B — keep the current architecture, but simplify specific components.**

Review baseline: b16c2a49cf40f3952f4d8322b30ac261c9375d29, including BLUDA0 fix
79b93e7413bdd2569b108993580e753fbd01252f. Pinned original C:
a77dfb96cb91780ca334d0d4cfd86957558007e0.

This report follows the user's redirected brief: **assume correctness within the documented,
accepted scope; evaluate the engineering choice**. Existing reports and evidence are trusted
inputs, not certificates being independently renewed. Source inspection establishes how the
architecture works and what alternatives would have to preserve. This is neither a defect
catalogue nor an implementation proposal for another Phase 4 goal.

Review worktree: /Users/eduard/sandbox/doom-evm-memory-audit.
Branch: audit/phase4-memory. One Codex reviewer; no subagents or model comparison.
Only this report and the PHASE4-PLAN.md documentation checkpoint are deliverables.

## 1. Executive architectural verdict

**Sol made the right fundamental choice for this project's compatibility target. It is not
the simplest possible way to make a playable DOOM port; it is a defensible way to preserve
the particular native behaviors this port has chosen to retain.**

The current implementation is already a compromise between logical objects and a physical
heap emulator. Gameplay lives in typed Solidity structures with stable IDs. Immutable assets
remain in resource contracts. A virtual allocator ledger preserves native allocation order
and offsets, and a bounded reader reconstructs selected bytes only when rendering needs
them. It does **not** retain a complete 64 MiB native byte heap.

The reason to retain that ledger is concrete: original rendering can observe bytes outside
a logical resource, including a neighboring allocator header. A design containing only
resource bytes and logical actors has discarded information needed to reproduce that
observation. Initializing resource tails to zero does not recover a source-written header
value.

There is nevertheless avoidable complexity:

- Native ABI sizes appear both in generated layout definitions and hand-maintained constants.
- Startup and ordinary rendering implement substantially the same cache ownership operation
  through separate wrappers.
- The important boundary between native allocation semantics and temporary EVM decoding is
  distributed across several adapters.

Consolidate those definitions and operations when this subsystem is next changed. Retain the
allocator algorithm, stable gameplay IDs, sparse backing reader and explicit initialization
policy. Do not undertake a heap rewrite merely to reduce the number of memory-related modules.

**A significantly simpler, generally equivalent replacement has not been established.**
The most dramatic simplifications either change the pixel compatibility contract or
specialize to heap relationships observed in finite recordings. A complete virtual byte heap
moves in the opposite direction: broader fidelity at substantially greater integration cost.

This conclusion follows from the information each design must retain. Passing tests do not
establish that an architecture is optimal.

## 2. The underlying engineering problem

### Three distinct memory problems

1. **Logical gameplay identity:** actors, thinkers, sectors and references must survive calls
   while preserving source traversal and mutation order.
2. **Native allocation behavior:** sizes, tags, owners, ordering, reuse, purging and coalescing
   determine some subsequently observable bytes.
3. **EVM persistence:** call memory disappears after a transaction. Persistent logical state
   and native allocation metadata must be restored without counting each temporary resource
   decode as another original allocation.

These problems do not require the same representation. Conflating them into one universal
heap would make the port harder to maintain.

Original allocation scans from a rover, purges eligible cache blocks, splits only when the
remainder exceeds MINFRAGMENT, clears owner slots on free and merges neighboring blocks.
Those rules determine which allocation follows a resource. See original
[z_zone.c:122–288](../original/DOOM/linuxdoom-1.10/z_zone.c#L122) and
[W_CacheLumpNum](../original/DOOM/linuxdoom-1.10/w_wad.c#L476).
They are normally implementation details when clients stay within their objects.
Here, original clients sometimes expose them.

### Why logical resource bounds were insufficient

| Accepted historical observation | What the original draw reads | Architectural implication |
|---|---|---|
| PLAYW0, browser tic five | frac = −1; masked index 127; source offset 1021 + 127 = 1148, twenty bytes beyond a 1128-byte lump. This is the successor header's ID field; its low byte is 17. | Zero padding or a resource-only representation loses a source-written, layout-dependent value. |
| BLUDA0, captured tic 445 | frac = −39; source offset 205 + 127 = 332 for a 324-byte lump. After four alignment bytes, the sample reaches byte four of the successor header: ABI padding. | Allocation geometry locates the byte, but original source writes do not determine its value. A deterministic platform policy is also needed. |

These are trusted findings from the existing
[PLAYW0 diagnosis](../artifacts/phase3/historical-draw-diagnosis.json) and
[BLUDA0 report](DRAWBOUNDS-BLOOD-CRASH.md). The source operations are
[R_DrawColumn](../original/DOOM/linuxdoom-1.10/r_draw.c#L132) and
[R_DrawMaskedColumn](../original/DOOM/linuxdoom-1.10/r_things.c#L351).

A resource-tail exception could reproduce either pictured pixel. It would not explain which
byte to use when the neighboring allocation, tag, size or write history changes.

### Which original C behaviors are essential?

**Preserve as observable requirements:** live gameplay identities and reference relationships,
thinker order and deferred removal, cache ownership/tag transitions, allocation footprints
and chronology where these influence supported backing reads, and the chosen initialization
profile. The original sampling arithmetic belongs to the retained behavior, even when it
would be undesirable in a new renderer.

**Preserve as an explicit native profile:** integer representation, endianness, structure
layout and alignment. The port uses LP64 headers of 40 bytes, zones of 56 bytes and eight-byte
allocation alignment. Upstream rounds requests to four bytes. This is already a selected
platform adaptation, not reproduction of every original executable.
See [allocator scope](PHASE3-ZONE.md) and
[generated layout](../src/doom/native_zone_layout.sol#L71).

**Do not elevate into universal requirements:** arbitrary process addresses, unknown pointer
bytes, arbitrary initial malloc contents, or every stale byte from every possible native
execution. Original [I_ZoneBase](../original/DOOM/linuxdoom-1.10/i_system.c#L76) uses malloc;
it does not specify an initial zero heap. C padding is also not a portable pixel specification:
the language permits unspecified padding after member stores. The practical target must
name a compiler/ABI/profile. See the primary
[WG14 padding clarification](https://www.open-std.org/jtc1/sc22/wg14/www/docs/dr_222.htm).

A logical WAD overread does not by itself establish an overrun of the underlying malloc
allocation: DOOM subdivides a larger zone. Conversely, being inside that allocation does
not make padding source-defined. Calling every such observation “undefined behavior” and
discarding it would obscure the actual design decision.

**The fundamental assumption is product policy:** must the port preserve allocator-dependent
pixels, or may it define cleaner resource-boundary rendering? Both are legitimate projects.
The existing project chose the former. This review compares alternatives against that choice.

## 3. Why the current solution works

The source and historical progression support the following rationale. This is a reconstruction
of the engineering decision, not a claim about the author's private intent.

### Separate representations for separate responsibilities

| Layer | Representation and responsibility | Main source |
|---|---|---|
| Gameplay | Typed state, stable IDs, logical references and source list order | [p_game_state.sol:427](../src/doom/p_game_state.sol#L427), [p_heap.sol:27](../src/doom/p_heap.sol#L27), [p_tick.sol:48](../src/doom/p_tick.sol#L48) |
| Native allocation | Block IDs, virtual byte offsets, rover, links, tags and owner slots | [z_zone_types.sol](../src/doom/z_zone_types.sol#L6), [z_zone.sol:68](../src/doom/z_zone.sol#L68) |
| Allocation chronology | Source-derived startup/setup operations, gameplay lifetimes and semantic cache calls | [DoomZoneStartup.sol:147](../src/evm/DoomZoneStartup.sol#L147), [p_zone_setup.sol:111](../src/doom/p_zone_setup.sol#L111), [p_heap.sol:186](../src/doom/p_heap.sol#L186), [w_zone_cache.sol:18](../src/doom/w_zone_cache.sol#L18) |
| Byte observations | Lazy reconstruction of selected header fields, authenticated cached bytes and eligible initial zeros | [z_zone_backing.sol:92](../src/doom/z_zone_backing.sol#L92) |
| Persistence | Load authoritative state, restore aliases and transient resources, store final state | [Doom.sol:69](../src/evm/Doom.sol#L69), [DoomGame.sol:90](../src/evm/DoomGame.sol#L90), [DoomGame.sol:196](../src/evm/DoomGame.sol#L196) |

Stable logical IDs solve reference management; virtual offsets solve physical-byte observations.
Combining the two would spread native address semantics through gameplay without eliminating
allocator work. Stable IDs intentionally do not constitute a general emulator of all
possible native stale-pointer/address-reuse behavior; that broader target is not assumed here.

Immutable resource bytes and native cache ownership are likewise different things. Reading
a lump again during a later EVM call should not imply another original allocation.
An existing composite can be rebuilt transiently without retagging its patch dependencies;
a purged composite must follow original regeneration chronology.
[r_data.sol:294–379](../src/doom/r_data.sol#L294) expresses that distinction.
This is necessary adaptation to transactional execution, not duplicate caching for its own sake.

### A narrower backing model than the name suggests

[bindColumn](../src/doom/z_zone_backing.sol#L45) returns immediately when the ordinary
128-sample range fits within the logical source. Otherwise it requests a bounded tail,
with a 256-byte guard. The reader follows live blocks and reconstructs selected domains;
it does not materialize every native body or pointer.

The renderer consumes a tail and a readable mask rather than traversing allocator structures
itself ([r_draw.sol:48–61](../src/doom/r_draw.sol#L48)).
This is a useful boundary: most engine code uses logical data, while the compatibility
requirement is concentrated at a byte-observation interface.

### Why deterministic initialization was added

Physical reconstruction answered **where** BLUDA0's sample landed. It could not answer
**what initial padding value** malloc happened to supply. Reproducible EVM execution needs
an explicit answer.

The selected policy initializes the initial virtual zone to zero while retaining strict
source-written-only diagnostics. Policy selection happens before startup in
[Doom.sol:34–50](../src/evm/Doom.sol#L34) and
[DoomGame.sol:143–155](../src/evm/DoomGame.sol#L143).
The [existing report](DRAWBOUNDS-BLOOD-CRASH.md) treats this as a platform policy.

That is more principled than returning zero on any unsupported read. Historical header
ranges and maximum requested payload extents exclude potentially overwritten bytes from
initial-zero provenance. Free, coalescing and Clear do not reset that history.
See [z_zone.sol:123](../src/doom/z_zone.sol#L123) and
[initializedBytes](../src/doom/z_zone_backing.sol#L179).

Its generality is **address- and history-based, not sprite-based**. Its deliberate limit is
that deterministic initial conditions do not reconstruct every subsequent write.
A complete initialized byte heap could cover more; the current policy avoids paying for
that capability before it is required.

## 4. Alternative architectures

### Alternative 1 — Pure logical objects and strictly bounded resources

Remove the virtual allocator. Keep logical gameplay objects and immutable resources; reject,
clamp, wrap or otherwise define rendering at resource boundaries.

This has the lowest conceptual and persistence cost. It removes allocation chronology from
gameplay/renderer integration. It would be my preferred architecture for a new portable
DOOM-inspired engine whose contract is game rules and conventional graphics.

It cannot preserve the retained observations without another mechanism. Rejecting recreates
the known failure; clamping or logical wrapping changes the selected byte; zero padding does
not produce PLAYW0's header value. Retaining the arithmetic while omitting its observed
address domain is insufficient.

**Judgment:** a viable product alternative, not an equivalent replacement. Its simplicity
is purchased by changing the specification.

### Alternative 2 — Resource-boundary compatibility buffers

Extend each resource with a tail so the draw loop sees enough bytes.

Three versions must be distinguished:

- **Uniform padding:** simple, but cannot represent both source-written neighbor fields
  and history-dependent bytes.
- **Frozen, source-derived trailers for a particular startup:** potentially adequate for
  finite recordings, but assumes stable adjacency and ownership. Existing lifecycle evidence
  observes no purge in its finite runs, not permanent neighbor stability.
- **Dynamic trailers:** regenerate after relevant allocation, tag, ownership or provenance
  changes. This can preserve behavior, but requires the information supplied by the current
  allocator and adds trailer invalidation.

The coverage limitation is explicit in the
[native lifecycle report](../tools/reference/phase3_zone_lifecycle/README.md).

Putting compatibility at the resource boundary is good design. **The current tail binding
already does much of that.** Persisting extended buffers would add derived state rather
than necessarily remove complexity. Transient tail caching could reduce repeated work,
but that is an optimization, not a replacement architecture.

**Judgment:** keep the boundary interface; reject uniform or frozen trailers as a general
substitute for the current model.

### Alternative 3 — Selective neighborhood model

Represent only allocations that can influence resource-tail reads, nearby headers and
relevant write provenance. Omit unrelated global heap detail.

This is the strongest candidate for a materially smaller equivalent model. The renderer
does not need every object's contents or native absolute host addresses. Local relative
geometry and relevant fields could be sufficient.

The hard part is deciding what stays irrelevant. Rover scans, purging, splitting and
coalescing can make a currently distant allocation affect a future neighbor.
Actor/mover **payload contents** can often be omitted, as they are now.
Their **allocation footprints and timing** cannot generally be omitted on the same basis.
See the allocator's [scan/purge/split operations](../src/doom/z_zone.sol#L74).

This could be superior under a durable contract fixing resource neighborhoods and excluding
interference from other allocation activity. Establishing and maintaining that contract
may cost more than retaining the relatively small original allocator. Creating new separate
asset arenas would itself change native geometry; it is not a free implementation detail.

**Judgment:** credible if metadata becomes a meaningful bottleneck and noninterference can
be established across the intended scenario set. Not presently justified as a simpler
general replacement.

### Alternative 4 — Canonical virtual byte heap

Keep native memory in a byte-addressed virtual zone, probably sparse pages/words with
provenance. Reads return recorded bytes rather than reconstructing them from providers.

This is the most coherent direction if future features require frequent observations of
mutable bodies, old freed contents or many different cross-object reads. Writes establish
the bytes, potentially eliminating numerous special reader cases.

Its total integration cost is high. Either gameplay fields become heap accessors, or logical
mutations also update native-format bytes. The latter creates two mutable representations
of the same state; the former changes the port's programming model. Every retained write,
endian rule and layout relationship needs representation. Virtual pointers would still need
an explicit policy: a byte heap cannot reproduce arbitrary native process addresses.

Immutable WAD bytes can remain indirect, but pages mixing immutable data, mutable writes,
initial zeros and unknown bytes again need provider/provenance rules. Dense persistence of
64 MiB is unattractive in EVM; sparse pages reduce that cost without removing write tracking.

**Judgment:** broader capability, substantially greater implementation debt now. Reconsider
only if required observations outgrow the current narrow reader.

### Alternative 5 — Allocation log plus reconstruction at call boundaries

Persist source-semantic allocation/free/tag events, reconstruct the allocator on load,
and use the resulting geometry. Periodic snapshots can bound replay length.

This is a genuinely different persistence approach. Append-only records could avoid copying
a larger allocator structure, and histories would be naturally inspectable.

However, allocations and owner clearing affect execution immediately. The allocator still
has to run. Loading now requires replay; without snapshots cost grows with history, while
snapshots introduce both a snapshot format and a log lifecycle. The log may retain operations
whose results the current state already summarizes.

**Judgment:** a defensible storage tradeoff, but no clear complexity advantage here.
Do not introduce event sourcing without a concrete storage-versus-replay cost case.

### Alternative 6 — Keep the hybrid, normalize metadata and interfaces

Keep logical gameplay, immutable resources, original allocation rules and lazy observations.
Use one canonical ABI definition and one semantic cache ownership operation.

A more ambitious version could separate active allocator topology from a compact union of
historically written ranges. Active blocks answer current header/ownership questions;
the range set answers whether a byte can still inherit initial zero. This expresses the
provenance requirement without making each old block record serve two roles indefinitely.

That could reduce retained state, but interval insertion/coalescing, stable block references
and traversal semantics become new obligations. The current append-only history is simple
to reason about. Fewer retained records do not automatically mean a simpler implementation.

**Judgment:** adopt the small consolidation direction. Defer historical-state replacement
until its benefit justifies additional machinery.

## 5. Comparative decision matrix

These are qualitative engineering estimates, not benchmarks. “Equivalent” means preserving
the chosen observable native profile, not every possible C execution.

| Architecture | Required observations | Complexity / maintainability | Runtime overhead | Storage / call memory |
|---|---|---|---|---|
| Current hybrid | Accepted within documented scope | Moderate; explicit roles and several integration boundaries | Allocator work, state copies, bounded tails and history scans | Metadata and logical state/history; no full byte heap |
| Pure logical resources | Changes the boundary-read contract | Lowest; straightforward ownership | Lowest compatibility overhead | Smallest compatibility state |
| Boundary buffers | Static: generally insufficient. Dynamic: can preserve | Static: low. Dynamic: invalidation dependencies | Fast reads after materialization; update/copy costs | Additional tails if persisted; ledger often remains |
| Selective neighborhoods | Conditional on noninterference | Smaller representation; subtle omission rules | Potentially less metadata work | Potential savings depend on what can be excluded |
| Canonical byte heap | Can cover broader observations under a profile | Simple address-space concept; expensive write integration | More byte/word accesses and mutation bookkeeping | Dense: high. Sparse: workload-dependent pages/provenance |
| Allocation log + replay | Can preserve complete event semantics | Replay/checkpoint lifecycle adds concepts | Increasing replay cost between snapshots | Log plus snapshots; reconstructed call state |
| Consolidated hybrid | Same intended contract as current | Best incremental direction; fewer duplicate definitions | Approximately current; no speedup assumed | Approximately current; optional later history compaction |

| Architecture | Source / C-profile fidelity | Generality | Implementation / integration difficulty | Long-term debt |
|---|---|---|---|---|
| Current hybrid | Original allocation semantics and selected physical observations | Good within supported byte domains; deliberately incomplete elsewhere | Already integrated | Mirrored allocation call sites and historical-state growth |
| Pure logical resources | Logical game fidelity; different boundary pixels | Broad for a different graphics contract | Modest from scratch; migration changes behavior | Low technical debt, explicit compatibility divergence |
| Boundary buffers | Dynamic can preserve profile; static assumes layout | Static version brittle under layout changes | Low for padding; higher for exact invalidation | Exceptions or duplicated derived state |
| Selective neighborhoods | Relevant semantics if excluded effects are irrelevant | Depends on stability of exclusion arguments | High reasoning burden despite fewer records | Hidden coupling when new allocations invalidate assumptions |
| Canonical byte heap | Broadest potential byte fidelity; still ABI/policy-specific | Strong if required writes are modeled | Highest: accessors or pervasive write synchronization | Broad byte-level compatibility surface |
| Allocation log + replay | Preserves source-semantic sequence | Broad, with growing history | Medium/high: event/snapshot schema and replay | Unbounded log or checkpoint/compaction machinery |
| Consolidated hybrid | Retains current fidelity boundary | Same as current; can expand deliberately | Low for consolidation; substantial for history redesign | Less duplication, remaining intentional compatibility cost |

**Preferred: consolidated hybrid.** It retains the state that explains required observations
without building a universal native-memory emulator.

## 6. Complexity and maintenance tradeoffs

### Essential complexity

Consider two executions with the same logical resource bytes and camera, but different
permitted neighboring headers. Original sampling can return different values.
An equivalent implementation must retain that distinction, derive it from other retained
state, or establish that the executions cannot occur. A resource ID alone cannot encode it.

“Initially zero” and “unknown after writes” are also distinct states. Eliminating provenance
history requires a different policy, a fuller byte store, or a noninterference argument.
The history is not incidental bookkeeping.

Transactional execution adds the native-cache-versus-temporary-parsing distinction. Original
chronology must survive without treating reconstruction as new native work.
The [persistence interface](PHASE3-INTERFACES.md#ownership-and-memory-aliases) and
[DoomGame.load](../src/evm/DoomGame.sol#L196) are appropriate boundaries.

### Accidental complexity worth reducing

**Duplicated ABI definitions.** Generated
[NativeZoneLayout](../src/doom/native_zone_layout.sol#L71) supplies the layout, while
[ZoneConst](../src/doom/z_zone_types.sol#L36) repeats header/zone/alignment sizes,
[DoomZoneStartup](../src/evm/DoomZoneStartup.sol#L33) repeats primitive/structure widths,
and [p_zone_setup.sol:130](../src/doom/p_zone_setup.sol#L130) uses a literal pointer stride.
Consolidation reduces places that must agree without changing allocation behavior.

**Duplicated semantic cache operation.** Compare
[DoomZoneStartup.cache](../src/evm/DoomZoneStartup.sol#L113) with
[W_ZoneCache.cacheLump](../src/doom/w_zone_cache.sol#L18).
Both resolve an owner, allocate a miss or retag a hit. Startup adds observations.
A shared operation with a separate observation wrapper would make ownership behavior
authoritative in one place. Preserve call order and keep quiet parsing distinct.

**Unclear vocabulary for the fidelity boundary.** “Physical backing” and “initialized”
can suggest a complete heap. Describe the system as a *virtual allocator with lazy byte
provenance*: source-written, initial-profile bytes and unknown. This clarifies future
extension decisions without introducing a new runtime abstraction framework.

### Deliberate costs

Historical block records are appended in
[z_zone.sol:48–60](../src/doom/z_zone.sol#L48), then scanned for initialization provenance
in [z_zone_backing.sol:197–205](../src/doom/z_zone_backing.sol#L197).
Actor/thinker pools similarly retain stable slots
([p_heap.sol:27–55](../src/doom/p_heap.sol#L27)).
Thus representation cost can follow allocation history rather than only current live objects.
That is a long-term cost characteristic, not a claim of a failure in the accepted scope.

For tail length L and H historical records, initialization provenance requires a history
pass with bounded range exclusions; worst-case work can approach H × L.
The normal in-lump fast path avoids it. Bounding L does not bound H.
Separating active topology from historical exclusion ranges targets this cost more directly
than replacing the engine's whole memory model.

Recycling every logical ID, trimming every spare array slot or custom-packing storage are
not automatically simplifications. They can introduce lifetime rules, serialization formats
and extra load/store logic. The current compiler-managed state copy is straightforward
([Doom.sol:73–79](../src/evm/Doom.sol#L73)). Keep that advantage unless there is a concrete
reason to exchange it for bespoke persistence.

### Limits of the available cost evidence

The trusted [production memory report](../tools/reference/gameplay/PRODUCTION-MEMORY.md)
records about 19.7 MB at a historical initialization clone's engine boundary and about
11.9 MB at sampled render boundaries, despite the 64 MiB virtual zone. These are pre-BLUDA0
clone measurements with observer limitations. They illustrate that virtual zone size is not
EVM memory consumption; they do not isolate the current backing subsystem.

The [post-fix ledger](../artifacts/phase3/drawbounds-compatibility.json) records roughly
1.713 billion startup gas and 1.792 billion gas for captured tic 445.
These are whole-engine transactions. Neither they nor whole-contract code size establish
what an allocator redesign would save. This report claims no measured alternative speedup.

The real tradeoff is qualitative: reconstruction avoids retaining all native bytes, but
pays for metadata, provider logic and historical scans. A byte heap pays more directly for
writes and persistence. A logical-only port pays by changing the compatibility contract.

## 7. Recommended architecture

**Choose B. Keep the hybrid; simplify its definitions and integration points.**

Keep:

- Typed authoritative gameplay state and stable logical IDs.
- Immutable resources separated from native cache ownership.
- Source-order allocator metadata, including reuse, purge and ownership effects.
- A bounded byte-observation interface at renderer resource boundaries.
- Explicit initial-zone initialization and strict diagnostics; unknown bytes remain unknown.

Recommend only these near-term architectural cleanups, in a future authorized task:

1. **Use generated ABI layout as the single source for native sizes and offsets.**
   Keep semantic constants such as tags separate.
2. **Consolidate cache ownership operations shared by startup and runtime.**
   Keep source-derived ordering visible and observations outside the semantic primitive.
3. **Document the three representations and their owners together.**
   Gameplay state owns logical behavior; allocator metadata owns virtual geometry;
   immutable resources/current modeled fields plus provenance determine readable bytes.
   Temporary decodes are disposable.

These reduce maintenance dependencies. They are not promised gas optimizations and should
not expand into a generalized memory framework.

| Larger possible change | Evidence that would justify reconsideration |
|---|---|
| Active topology plus compact historical write ranges | History retention/scanning materially affects supported long-running scenarios, and a smaller representation preserves the same provenance distinctions |
| Selective neighborhoods | A durable noninterference argument excludes substantial allocator state across the intended scenario set |
| Canonical sparse byte heap | Required features repeatedly need mutable/stale body observations, making provider-by-provider reconstruction more complex than write tracking |
| Pure logical boundary semantics | An explicit product decision permits different allocator-dependent pixels |
| Allocation log persistence | A concrete storage-versus-replay analysis favors logs and bounded checkpoints |

Do not redesign for hypothetical scenarios. Equally, do not indefinitely grow the sparse
reader through individual field exceptions if its required observation domain becomes a
broad native heap. That would be the point to reconsider.

Explicit answers to the original decision questions, under the redirected brief:

- **A. Correct within documented scope?** Assumed as instructed; acceptance is not renewed
  or expanded by this report.
- **B. Is a full physical backing-memory model necessary?** No; the current implementation
  is not one. Some allocation geometry/history is necessary for the chosen observations
  unless an alternative derives it or establishes its irrelevance.
- **C. Can it be significantly simplified without losing correctness?** Local consolidation
  is credible. Removing the main compatibility mechanism while preserving the general
  contract is not currently justified. A small finite-trace solution is insufficient.
- **D. Is deterministic initialization sufficiently general?** Yes as an asset-independent
  initial-condition policy; intentionally no as a complete model of subsequent memory.
  It complements provenance rather than replacing it.
- **E. Keep, improve or redesign?** Improve incrementally; preserve the fundamental design.

## 8. Would you make the same decision from scratch?

**Yes to the hybrid; no to arriving at its policy and boundaries piecemeal.**

Given today's knowledge and the same fidelity requirement, I would start with typed gameplay
and immutable resources, then define one compatibility subsystem around a declared native
ABI/initial-memory profile, semantic allocation/cache operations in source order, a virtual
offset ledger, and a query returning a byte with its provenance.

I would separate logical object identity from observable native bytes before integrating
the renderer. I would make initial-zero behavior a named platform contract from the outset,
with strict diagnostics serving a different purpose. That avoids treating each newly
observed padding read as a new rendering problem.

I would not begin with a complete native byte heap or serialize every actor field into
native-format memory. The requirements justify retaining allocation footprints far more
broadly than payload bytes.

If the contract instead were “a maintainable DOOM port with well-defined graphics, without
preserving incidental allocator-dependent pixels,” I would choose logical resources and
explicit boundary semantics. That would be substantially simpler and an honest different
specification, not an equivalent implementation of this one.

The current approach is not uniquely possible or optimal under every objective.
It is the best-supported compromise for source traceability, retained pixel behavior,
transactional persistence and bounded implementation scope.

## 9. Is changing the existing implementation worth it?

**Small consolidation is worth doing when touching this subsystem. Replacing it now is not.**

A rewrite must repay more than its source-line count. It would affect startup ordering,
level setup, actor/mover lifetime, renderer caches and persistent-state interpretation.
Those integration costs exist even if a replacement allocator is short. The current
architecture has already paid them and preserves a useful separation between logical state
and selectively observable native memory.

No established performance requirement or measured subsystem bottleneck here justifies
paying that migration cost again. The radical simplifications also have not eliminated the
need to represent allocation-dependent observations: they omit, specialize or relocate it.

Adopt the documentation and direction in this review. Treat ABI/cache consolidation as
bounded maintenance; treat historical-provenance compaction as a separate decision requiring
a concrete reason. Keep the accepted implementation operational.
**Do not begin a heap redesign or another Phase 4 goal on the strength of this review.**

### Evidence and review boundary

Primary inputs are the linked source locations,
[Phase 3 scope](PHASE3-REPORT.md#scope-and-measurement-limits),
[allocator rationale](PHASE3-ZONE.md),
[backing integration](PHASE3-BACKING-INTEGRATION.md),
[native lifecycle observations](../tools/reference/phase3_zone_lifecycle/README.md),
[PLAYW0 diagnosis](../artifacts/phase3/historical-draw-diagnosis.json),
[BLUDA0 policy](DRAWBOUNDS-BLOOD-CRASH.md), and the
[post-fix checkpoint](../artifacts/phase3/drawbounds-compatibility.json).

The reviewed checkpoint SHA256 is
74447a9fe0ad870564fbe860022d08c8d23e3d1080ce9674cb151873992d00ca.
The historical Phase 3 acceptance certificate remains historical.

Earlier activity under the initial brief included focused verification. The user then
redirected the task to architectural evaluation. No correctness tests were started after
that redirect. Test results are not used as an argument that this architecture is best,
and no diagnostic code is delivered. Alternatives are reasoned designs, not implementations
or measured benchmarks. Engine code, existing tests and historical certificates were not
modified by this audit.
