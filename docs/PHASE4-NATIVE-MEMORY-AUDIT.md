# Native C memory compatibility audit

Status: audit and coordinating review complete; ready for Git integrator handoff. Owner: independent GPT-6 Astra audit agent; coordinating agent reviews and commits. Start: **2026-10-10T17:04:33Z**. Baseline: clean `feat/phase4-episode-completion`, `b12eb212fa1f33ba787490327e327611b156f9a0`; original DOOM pinned at `a77dfb96cb91780ca334d0d4cfd86957558007e0`.

Authorized scope: inspect original C, native harnesses and the existing hybrid typed-state/virtual-zone backing model; perform focused isolated test-only original-C experiments; document native profiles, provenance, C semantic limits, defects and recommendations. No production Solidity or original C changes, existing fixture rewrites, compiler-setting changes, main integration, push, external runtime interaction or full historical regression suite. This existing feature worktree is explicitly assigned for the audit; no new branch/worktree. Audit-owned paths: this report, `tools/reference/native_memory_audit/`, and `artifacts/phase4/native-memory-audit/`.

Dependencies: original C and existing native harness/profile adapters; current feature code and preserved evidence. Verification gates: reproducible small O0/O2/sanitizer experiments, original-source and executable hashes, exact byte/layout observations, profile/knownness analysis, source/link checks, clean handoff of only audit-owned changes. Stop condition: evidence supports the nine requested conclusions and KEEP/RESTRICT/REFACTOR recommendation; unresolved domains remain explicitly bounded. No engine acceptance claim.

## Executive finding

**Verdict: RESTRICT.** Retain the hybrid implementation, restrict native-equivalence claims to explicitly named profiles, and defer architectural refactoring. The new byte classes do not demonstrate that the hybrid architecture is wrong. Current layout constants match fresh measurements of all 26 recorded native types. The live-composite extension reconstructs bytes using the original-corresponding algorithm and verifies write coverage. The pointer extension is correct **conditionally** for the declared little-endian LP64 representation with every relevant data pointer below `2^48`; it is not a portable property of DOOM, C, or even all LP64 machines.

No production correctness defect was demonstrated in the reviewed domain. There are confirmed documentation/profile-accounting weaknesses and important coverage limits. Original `malloc`, current whole-zone `calloc`, per-allocation fill experiments, and separate per-block renderer allocation are different execution profiles. Equal pixels in selected tests do not make their heaps equivalent. `Strict` is a conservative diagnostic knownness policy, not a native execution environment in which unknown bytes cease to exist.

Fresh audit evidence comprises seven experiment builds and 66 processes: **63 successful observations and three expected unadapted-align4 sanitizer failures**. A separate inventory compiled and executed a complete native layout probe and compiled three ABI comparisons. The existing resource fixture has **963 texture records, 338 nonempty composites, and zero recorded unwritten composite bytes**; record 76's 512-byte digest matches the Episode diagnostic binding. These are not new whole-map native frame proofs. Earlier accepted tests, original C, fixtures, and the [previous architecture audit](PHASE4-MEMORY-AUDIT.md) remain unchanged.

## 1. Which native execution is being reproduced?

The defensible target is an **adapted Apple arm64 reference profile**, not the historical Linux executable. There is no single native profile shared by every test.

The checked compiler is `/usr/bin/clang`, reporting `Apple clang version 17.0.0 (clang-1700.0.13.5)` and `arm64-apple-darwin24.6.0`. The measured host is macOS 15.7.9/build 24G830, Darwin 24.6.0, arm64. No claim is made that this alone pins all linker/libc/SDK internals. Exact compiler commands, target, environment policy, generated-source hashes and executable hashes are in [experiment.json](../artifacts/phase4/native-memory-audit/experiment.json); current macros and fresh layouts are in [inventory.json](../artifacts/phase4/native-memory-audit/inventory.json).

| Profile/family | Compiler/configuration | Allocation, initialization and important adaptations | What its agreement establishes |
|---|---|---|---|
| Pinned original source | [Makefile](../original/DOOM/linuxdoom-1.10/Makefile): `gcc`, `-g -Wall -DNORMALUNIX -DLINUX`; no explicit optimization, language standard, target or compiler version; link `-L/usr/X11R6/lib -lXext -lX11 -lnsl -lm` | `I_ZoneBase` mallocs `mb_used*MiB`, default 6 MiB; original `Z_Malloc` rounds4. `doomdef.h` defines `RANGECHECK`; `USEASM` is commented out. | Source identity, not a fully pinned historical executable. ILP32 assumptions are evident from pointer-array `*4` allocation and pointer-to-int casts, but Makefile does not explicitly select i386. |
| Foundation numeric oracle | [reference.py](../tools/reference/reference.py): C99, O0/O2, `-fwrapv -fno-strict-aliasing -ffp-contract=off -fno-fast-math`; version/target asserted | Extracted functions, explicit host types/adapters; strict numeric sanitizer variants remove `-fwrapv` and have their own domains | Declared scalar vectors; no zone/heap equivalence |
| Phase2 data oracle | [reference.py](../tools/reference/phase2_data/reference.py), [compat.h](../tools/reference/phase2_data/compat.h): same pinned base flags; O0/O2; UBSan with shift disabled for mixed map run; separate full-UBSan clip run | Separate malloc per payload, explicit `0xa5`/`0x5a` fills, no-op free/tag, immutable WAD pointers, packed disk shims and simplified host structures. Its local PU constants are shim values, not native zone tags. | Original composite/lookup bytes and write coverage; not original allocator chronology or adjacency |
| Static renderer oracle | [build.py](../tools/reference/renderer/build.py), [host.c](../tools/reference/renderer/host.c): base flags, `-DNORMALUNIX`, forced standard headers/trace header, warning suppressions, Darwin `-Wl,-dead_strip`; O0/O2/ASan+UBSan | Independent calloc per header+payload, optional payload fill; original zone allocator is absent. Explicit disk packing/int32 obsolete field, pointer-sized arrays, uintptr alignment, visplane enclosing-object access adapters | Finite renderer outputs; not the gameplay arena layout |
| Gameplay/zone lifecycle | [build.py](../tools/reference/gameplay/build.py), [host.c](../tools/reference/gameplay/host.c), [lifecycle runner](../tools/reference/phase3_zone_lifecycle/reference.py): base flags plus `-fsigned-char`, normal Unix/header shims, O0/O2/ASan+UBSan; exact pin asserted through renderer builder | Actual original `z_zone.c`, align4→8; fixed64 MiB calloc arena; pointer-sized sector arrays; observation hooks. `DOOM_ORACLE_ALLOCATION_FILL`, when supplied, memsets **each rounded payload** after allocation. Most verification loops explicitly supply0 or0xa5. | Selected state/frame/normalized allocation traces under declared variants. Whole-arena zero and repeated allocation-fill0 are distinguishable on reuse. |
| Production UI/raw-input native | [UI runner](../tools/reference/ui/reference.py), [input runner](../tools/reference/input-runtime/reference.py): gameplay base; function/data sections and dead-strip; sanitized builds disable array-bounds check for original variable patch tails; input adds implicit-int warning suppression | Gameplay arena retained, but ST/HU/AM assets and UI allocations borrow separate immutable/calloc host buffers. Leak detection disabled in verification environment. | Declared composed outputs, explicitly excluding historical whole-process zone equivalence |
| Episode startup oracle | [runner](../tools/reference/episode_startup/reference.py): inherits gameplay/zone compiler chain, O0/O2/sanitized | Same adapted arena; original G_InitNew/G_DoLoadLevel/P_SetupLevel observations, no rendering/tics in startup scope | Nine-map startup/selected skill observations, not Episode render-tail or transition equivalence |
| Allocator/backing/blood/pointer component proofs | [allocator](../tools/reference/phase3_zone_allocator/reference.py), [backing](../tools/reference/phase3_zone_backing/reference.py), [blood](../tools/reference/drawbounds_blood/reference.py), [pointer](../tools/reference/episode_completion/pointer.py): GNU11, signed char, wrapv, no-strict-aliasing, O0/O2/ASan+UBSan; pointer proof omits irrelevant floating flags | Small calloc or explicitly seeded arena; actual align8-adapted original allocator plus extracted draw functions; controlled allocation history | Specified header/tail positions. Some scripts record rather than assert compiler identity; pointer proof itself does not record compiler version/target/executable identity. The new audit pins and records these. |

The selected macros actually emitted by the current compiler are recorded rather than guessed. Both base and gameplay include `RANGECHECK`, LP64, Apple/Mach and arm64 macros; the gameplay variant adds `NORMALUNIX`. `LINUX`, `USEASM`, `__BIG_ENDIAN__`, and `__CHAR_UNSIGNED__` are absent. Thus original `LINUX`-conditional headers are not literally the harness profile. WAD endian macros take the little-endian path. The harness may define its own compatibility types instead of including the original headers; each family above must retain its own identity.

Apple documents signed plain char, 32-bit int, 64-bit long and 8-byte pointers/alignment. Our executable measurement independently agrees; `boolean` is the original C enum and measures4 bytes, whereas `byte` is unsigned char. C++ bool layout must not be substituted. [Apple ABI documentation](https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms).

| Measured/compiled ABI | int/long/pointer | memblock size/alignment | memzone size | Header offsets size,user,tag,id,next,prev |
|---|---:|---:|---:|---|
| Current arm64, executable measured | 4/8/8 | 40/8 | 56 | 0,8,16,20,24,32 |
| Modern Clang i386 Linux, **compile only** | 4/4/4 | 24/4 | 32 | 0,4,8,12,16,20 |
| Modern Clang x86_64 Linux, **compile only** | 4/8/8 | 40/8 | 56 | 0,8,16,20,24,32 |

The compile-only comparison is not historical GCC execution or a cross-platform gameplay proof. Matching LP64 structure offsets also does not establish matching pointer placement, allocator bytes, calling convention, libraries or sanitizer behavior. The [layout exporter](../tools/reference/phase3_zone_lifecycle/layout.py) records compiler metadata from constants rather than verifying the compiler itself; fresh audit measurement closes that gap for this checkout, not for arbitrary future regeneration.

## 2. What original C actually writes

[Original z_zone.c](../original/DOOM/linuxdoom-1.10/z_zone.c) is the allocation authority. `Z_Init`/`Z_ClearZone` establish the cap, first free block, links, user fields and size. They do not clear the zone or initialize every tag/ID/padding byte. Splitting writes the new fragment's size, user, tag and links but leaves its ID untouched. Allocation writes tag/ID/user and owner slot; free writes user=NULL, tag=0, ID=0 and may coalesce links/sizes. Neither free nor Clear erases old payloads or retired headers. Original `Z_Free` is not libc `free`; the encompassing arena allocation stays live.

Other initialization is local and must not be generalized: [P_SpawnMobj](../original/DOOM/linuxdoom-1.10/p_mobj.c), lines490–491, explicitly memsets the entire object; [I_AllocLow](../original/DOOM/linuxdoom-1.10/i_system.c), lines147–152, mallocs then zeroes; `W_ReadLump` writes lump bytes; `R_GenerateLookup` zeroes its local patch-count array. [R_GenerateComposite/R_DrawColumnInCache](../original/DOOM/linuxdoom-1.10/r_data.c), lines179–285, copy covered posts, preserve original overlap order and the negative-origin source-position quirk, and leave uncovered composite bytes alone. Static storage starts initialized; malloc backing is not specified as zero.

The original renderer's masked sample can cross a **logical lump/composite** end. That is not automatically an ASan allocation-boundary crossing: gameplay's entire64 MiB zone is one host allocation. Conversely, a byte being inside that arena and passing ASan does not prove every original derived-pointer, subobject, lifetime or effective-type expression valid ISO C. Byte inspection through an enclosing allocation is a stronger observational basis than pretending that a logical WAD length is the host allocation size. Our snapshots use the arena base for raw observations, while the extracted renderer retains its original pointer expressions. No conclusion depends on treating every logical overread as either universally defined or universally undefined.

Relevant language classifications are distinct:

| Category | Classification and implication |
|---|---|
| Initialized unsigned-byte data/copies | Defined operations within valid bounds; the resource/generator supplies the value. |
| Type widths, signed char, integer narrowing, negative signed right shift, pointer conversions | Implementation choices requiring the pinned ABI/compiler. |
| Structure padding following member stores | Unspecified by C; observed preservation of calloc bytes is a compiler/runtime profile fact. |
| Uninitialized malloc bytes | Indeterminate; repeated observations establish no portable value. Do not equate every character observation with a diagnosed trap. |
| Misaligned typed access; invalid pointer arithmetic/array bounds; signed overflow without a defining extension | Undefined domains, separately bounded or adapted. |
| Original `block->user > (void**)0x100` | Relational comparison outside a common object is not portable ISO C; native behavior remains an implementation-profile observation. |

These distinctions follow C11 draft §§6.2.6.1,6.3.1.3,6.3.2.3,6.5,6.5.6–8 and7.22.3. [WG14 N1570](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf). C99-based harnesses do not acquire a universal definedness certificate from this classification.

`-fno-strict-aliasing` constrains optimizer assumptions; it does not define every invalid pointer expression. `-fwrapv` supplies signed-overflow behavior, not heap initialization, universal bounds validity or pointer-address identity. Native `--strict` removes wrapv and deliberately exposes additional original-C UB; it is unrelated to the Solidity `initializeGameStrict` switch. Compiler option meanings are documented by [Clang](https://clang.llvm.org/docs/UsersManual.html).

## 3. Actual mode and provenance matrix

The model is typed gameplay plus a physical allocation ledger, not a complete byte heap. [z_zone.sol](../src/doom/z_zone.sol) preserves allocator order with measured LP64 align8 sizes, indexed links/owners, historical header records and monotonic requested `payloadExtent`. [native_zone_layout.sol](../src/doom/native_zone_layout.sol) is generated from original `sizeof/offsetof`; source-written integers are emitted little-endian. Bodies are reconstructed only for supported ownership classes. A uint8 virtual tag is sufficient for the declared original tags, not arbitrary native int tags.

The flags in [ZoneState](../src/doom/z_zone_types.sol) are **independent booleans**; `episodeMode` is a separate application/lifecycle selector. There is no hidden three-valued native-mode enum.

| Entry point/policy | Initial-zero flag | Pointer-high flag | Effect |
|---|---:|---:|---|
| `Z_Init` default; internal `DoomGame.initializeNative`; public `initializeGameStrict` | false | false | Source-written-only backing diagnosis; unknown samples reject |
| Public `initializeGame`, UI and raw-input initializers | true | false | Add eligible untouched initial-zero bytes; pointer bytes still unknown |
| Public `initializeEpisode` | true | true | EpisodeStartup receives initial-zero=true; Doom then explicitly enables bounded pointer high bytes |
| Internal `EpisodeStartup.initialize(..., deterministicInitialization)` | caller chosen | false by default | Startup alone does **not** select the pointer predicate |
| High-bytes-only combination, demonstrated by component test | false | true | Coherent independent assumption: pointer high bytes without initial-zero padding; no public initializer currently selects it |
| Zone-disabled static/resource consumers | no arena | no arena | Logical resources only; this is outside the physical-tail policy |

[Z_ZoneBacking.tailWithProvenance](../src/doom/z_zone_backing.sol), lines92–249, exposes the following categories. `tail` converts2/3 to the ordinary known marker1; [R_Draw](../src/doom/r_draw.sol), lines51–60, rejects any sampled tail byte without marker1. This conversion does not discard the diagnostic provenance API.

| Byte source | Supplied bytes and reason | Native assumptions / when UNKNOWN | Strict and legacy/Episode behavior |
|---|---|---|---|
| Current header size/tag/ID, provenance1 | Little-endian integer bytes reconstructed from current allocator state; ID only if `idKnown`; initial first-free tag excluded until known | Measured offsets, widths, original writes and matching allocation chronology. Initial/new-fragment ID remains unknown even when a particular heap happened to contain zero. Retired headers are not read as current headers. | Enabled in all physical-zone modes |
| Live cached WAD owner, provenance1 | Exact authenticated lump bytes, capped by logical lump length and current block ownership | Cached owner must still identify this allocated block. Depends on immutable source payload/no unmodeled mutation. Slack and freed/stale ownership give no resource-byte claim. | Enabled in all modes |
| Live composite owner, provenance1 | Current generated payload, including adjacent texture; original-corresponding generator tracks every written byte | Owner namespace is `numlumps+texture`; allocated/current-owner checks; write coverage must be complete or `UndefinedComposite` rejects. Freed/unmodeled payload remains unknown. | **Extension is shared across modes**, not Episode-only; it adds source-written evidence |
| Untouched initial zone, provenance2 | Zero in eligible virgin slack/header padding/free space | Requires explicit zero initial arena **and pinned observed preservation of those bytes**. `initializedBytes` excludes every historical header's size and user-through-prev region and every historical requested payload extent. Prior-body/header writes, out-of-zone addresses and pointer fields stay unknown. This is conservative and may reject physically zero bytes. | Disabled Strict; enabled ordinary/UI/input and Episode |
| Current header user/next/prev high bytes, provenance3 | Only relative offsets14/15,30/31,38/39 become0 | Little-endian eight-byte data-pointer representation, all relevant values `<2^48`, including null/unowned2 encoding. Applies to current allocated **or current free** headers whose pointer fields were written. Not retired headers, not pointer-bearing bodies. Lower bytes remain unknown. | Disabled legacy/Strict; enabled by public Episode initializer |
| Mutable actor/map/special bodies, retired headers, freed written payload | No invented value; data buffer0 is merely a placeholder while provenance0 | Many bytes could be reconstructed with more source-write/history accounting, but current implementation does not do so | Unknown in all modes, except eligible never-written initial space; fail only when an unknown byte is actually sampled |
| Outside arena / unsupported tail span | No backing claim | `bindColumn` sizes a bounded ordinary-column tail and rejects excessive required span; invalid block/range rejects | No policy turns invalid memory into known memory |

Initial-zero exclusion tracks possible body writes conservatively by **requested payload size**, not a complete store log. Current production callees must remain within that declared allocation domain. The native allocation-fill0xa5 hook writes rounded slack as well and is therefore a distinct adversarial profile, not a profile in which virgin-zero bytes can universally be reused as evidence. Header padding is not an original explicit write: code comments calling all initialization effects source-defined would be misleading.

The composite path was examined for an unsafe “new bytes means written” assumption. [R_Data.generateComposite](../src/doom/r_data.sol), lines305–358, maintains a separate coverage buffer, follows patch/post copy order, and rejects holes in every densely assigned composite column. `compositeBacking` uses `nativeCall=false`; patch loading bypasses native cache calls, and allocation, purge, tag/owner/rover effects are not replayed. Since lookup assigns composite columns consecutively with the original64KiB guard, successful coverage checks cover the whole payload. An existing `compositeReady` value is trusted as the generator's internal invariant, not a public untrusted byte injection. The [dedicated test](../test/unit/CompositeBacking.t.sol) checks unchanged encoded zone state and freed-payload rejection; it was inspected, not rerun by this audit.

## 4. Focused experiments and existing evidence

[probe.c](../tools/reference/native_memory_audit/probe.c) includes a temporary copy of original `z_zone.c` and mechanically extracted unchanged `R_DrawColumn`/`R_DrawColumnInCache`. The only allocator adaptation in the supported variants is the existing align4→8 change. Original files are not edited. [run.py](../tools/reference/native_memory_audit/run.py) runs three repetitions of each selected profile/policy and preserves commands, exact stdout/stderr and source/executable hashes. No engine, Anvil, browser or external runtime is started.

| Experiment | Actual result | Interpretation |
|---|---|---|
| O0/O2/ASan+UBSan, calloc/malloc-zero/0xa5/raw-malloc, three processes each | 36 successful runs; raw pointer bytes and addresses vary; all observed relevant pointers satisfy `<2^48` | Conditional high-byte predicate holds in these observations; low addresses are not constants |
| Auto-var-init=zero, same four policies/repetitions | 12 successful runs; 0xa5 heap padding/slack stays0xa5 | Automatic-variable initialization does not initialize the malloc arena or eliminate these cases |
| `-fno-wrapv`, same four policies/repetitions | 12 successful runs; tested memory results agree | These deliberately small arithmetic inputs do not overflow. This does **not** justify removing wrapv from gameplay |
| Original unmodified align4, O2, calloc, three processes | Three successful hardware executions with different allocation offsets | Lack of an immediate crash is not ABI correctness |
| Original align4, O2+ASan/UBSan, calloc, three processes | All three fail as expected at original `z_zone.c:254`: member access through misaligned memblock requiring 8-byte alignment | The existing align8 adaptation solves a measured modern-ABI issue; restoring align4 on this host is wrong |
| Current ABI layout | All 26 original measured type layouts equal the existing layout fixture | No discovered stale size/offset or Apple-harness layout mismatch |

In align8 runs, allocations of1,17,64 bytes yield headers at56,104,168,272 and block sizes48,64,104,7920. Free/coalesce removes the middle live header from the list but retains its physical bytes. Clear and reuse7 leave the earlier17-byte0x22 body at arena144..160 while changing the new body at96..102 to0x44. The model's historical exclusion is therefore necessary; neither `Z_ClearZone` nor reuse implies reinitialization.

For current header padding4..7, calloc and malloc+memset0 produce `00000000`; explicit0xa5 produces `a5a5a5a5`, including under auto-var-init. Raw malloc happened to produce zeros in ordinary runs but `bebebebe` under ASan. **Neither raw-malloc observation is an expected native value.** ASan's allocator also concentrates zone addresses into only two observed bases across its12 runs; ordinary O0/O2 each had12. Sanitizer runtime changes allocator/address observations and does not establish unrestricted OS placement.

The synthetic Episode-shaped allocation of512 then4096 bytes reproduces the physical categories: sample527 is neighboring `user` byte7, sample559 is neighboring payload byte7. The original draw outputs0 and98 respectively, matching the actual raw bytes. The4096-byte payload is an explicitly written synthetic pattern; this experiment is **not** a substitute for a native E1M4 texture or frame proof.

For that64-byte tail, source inspection yields the following expected knownness masks for the analogous supported live payload. These are analytical policy masks, not a newly executed Solidity comparison:

```text
Strict:       1111000000000000111111110000000000000000111111111111111111111111
Initial-zero: 1111222200000000111111110000000000000000111111111111111111111111
Episode:      1111222200000033111111110000003300000033111111111111111111111111
```

Digits are the provenance classes above, relative to the next header start. Only explicitly initialized-zero policies support the second/third masks. In the cache-copy experiment, original negative-origin and overlapping posts produce `0a141516` followed by12 unchanged bytes: all00 with initial0, allA5 with initialA5. This shows why the current `written` buffer is required. The negative-origin behavior deliberately leaves the source at the original post start.

The read-only [checker](../tools/reference/native_memory_audit/check.py) additionally verifies preserved source/fixture identities and their finite bindings:

- **PLAYW0:** [historical diagnosis](../artifacts/phase3/historical-draw-diagnosis.json) records1128-byte lump, source offset1021 plus masked127 =1148, current next-header ID offset20, byte17. This is a layout/chronology-dependent source-written integer, not padding.
- **BLUDA0:** [retained native proof](../test/fixtures/drawbounds_blood/native.json) has nine O0/O2/sanitizer rows across seeds0,85,165; sample332 is neighboring header padding4. Three distinct pixels follow the seed. Source hashes and these relationships pass the new checker; this proof was not regenerated.
- **Episode:** [retained pointer proof](../artifacts/phase4/episode-completion/pointer-native.json) guards the three tested pointers; the audit verifies its host/runner/original-zone hashes and adds exact-profile repeated experiments. [Composite binding](../artifacts/phase4/episode-completion/composite-native-binding.json) identifies record 76 (32×16,512bytes), hash `bdf6cf3a76487e51c677749a4794c4a980f2e5470a5014c6c60ab289baed58ba`. All preserved 963 records are checked, including 338 nonempty and zero recorded holes. This is content evidence, not E1M4 allocation chronology or full-frame equality.

ASan checks real host allocation bounds and supported memory errors; it does not understand these unannotated Z_Malloc suballocations or all C subobject rules. ASan+UBSan do not track the initializedness of every byte; MemorySanitizer is the separate initialization detector and is not supported by this Apple arm64 toolchain/profile. No MSan run is claimed. [ASan documentation](https://clang.llvm.org/docs/AddressSanitizer.html), [MSan documentation](https://clang.llvm.org/docs/MemorySanitizer.html).

## 5. Explanations evaluated and direct answers

| Proposed explanation | Judgment supported by this audit |
|---|---|
| A. Hybrid is appropriate but more byte categories are encountered | **Supported.** PLAYW0 integer headers, BLUDA0 initial padding and Episode current pointers/composites are genuinely different provenance classes. Adding a general verified class is compatible with the architecture. |
| B. Wrong native layout or initialization is being modeled | **No current layout defect found.** Fresh26-type match. Initialization differs intentionally from original malloc; interpreting initial-zero as historical/source-mandated would be wrong. |
| C. Compiler/ABI mismatch explains the problem | **Historical-to-current mismatch is real and intentional.** Align4 fails on LP64; ILP32 headers differ. No evidence the current Solidity constants mismatch the pinned Apple harness. |
| D. The implementation is overfitting observed pixels | **No demonstrated value-specific patch.** Rules operate on current ownership, general fields and coverage, not map/lump/pixel names. The bounded-pointer assumption was motivated by a failing map, so its domain must remain explicit and independently tested. Broader future special cases without such provenance would be overfitting. |
| E. Some behavior is unspecified/undefined/nonportable | **Supported.** Padding and raw heap observations, pointer representation/placement, original pointer comparisons and negative-shift/bounds domains are not all portable C semantics. This coexists with valid source-written classes. |

1. **Exact execution profile:** adapted pinned Apple Clang 17/arm64 little-endian LP64, declared64 MiB zero-initial arena, align8 original zone chronology, immutable resource identity, recorded host adapters and per-test flags. Episode adds a pointer-value predicate. There is no full-process native Episode image pinned by those words alone, and historical Linux is a separate target.
2. **Defined versus other semantics:** explicit valid source writes supply resource/composite/integer content; layout/conversions require implementation choices; padding and malloc contents need separate treatment; remaining original UB is not erased by equal O0/O2 results. The table in §2 bounds the classification.
3. **Mode coherence:** coherent as independent knowledge assumptions. Strict is deliberately incomplete, deterministic adds virgin-zero facts, Episode combines that with bounded high-pointer facts. Shared live-composite reconstruction does not rely on Episode. Misnaming all three as native platforms would obscure this distinction.
4. **Episode pointers:** conditionally justified for the guarded representation/address domain, including current free/null and unowned2 headers. Not justified for lower bytes, retired headers, mutable pointer fields, tagged/authenticated pointer representations or arbitrary LP64 address spaces. Native acceptance should guard every newly sampled relevant pointer; the current small proof guards its three sampled fields only. EVM stores no real native process pointers to guard at runtime.
5. **Can flags eliminate cases without changing intended behavior?** No supported general solution was found. Auto-var-init has no effect on heap padding; optimization and no-wrapv do not supply initialization. Packing changes offsets/ABI; restoring align4 on LP64 is invalid; forcing a32-bit target changes the reference layout/chronology; disabling ASLR does not define padding and is unnecessary for a bounded high-byte predicate. Zeroing every allocation/composite or changing draw masks would change the declared behavior/profile. Keep current settings.
6. **Preserve hybrid versus simpler implementation:** preserve it. Pure logical resources cannot produce PLAYW0's header17 or the adjacent payload. A full virtual heap still needs an invented or explicitly selected pointer-address space, padding policy and every store; it does not resolve C underspecification. A sparse byte-write journal could recover additional historical scalar/body bytes but creates new fidelity/maintenance obligations. There is no measured necessity for that refactor now.
7. **Confirmed correctness defects:** none demonstrated in production's declared finite domain. The unadapted original align4 LP64 failure is a confirmed reference-portability defect already addressed by the existing adaptation. Stale comments/profile labels and incomplete profile manifests are confirmed reporting/tooling weaknesses, listed below, not evidence that current pixels are wrong.
8. **Portability limits:** different endian/ILP32/LLP64 layouts, compiler member-store/padding choices, wider/tagged pointers, ASLR/allocator regimes, nonzero initial backing, UI/global allocation chronology, mutated cached resources, arbitrary WAD holes and unsupported logical-tail spans require new profiles/proofs. Existing output equality is finite and does not prove all maps/tics/restarts/purges.
9. **Production changes now:** **none recommended on correctness grounds from this audit**. Preserve the flags, shared composite reader, unknown rejection and tests. Clarify profile contracts before broadening claims; add narrowly targeted future acceptance instrumentation only when extending the domain. This audit authorizes no engine patch or automatic later goal.

## 6. Required follow-up, optional work, and preserved decisions

**Must fix before a broader release/equivalence claim:**

- Keep the exact adapted target/profile next to every native-equivalence claim. Explicitly distinguish initial calloc, per-allocation fill and borrowed UI resources. A compiler-version string alone is not full runtime identity.
- Correct current descriptions when those files next change: `z_zone_backing.sol`'s opening “No address, pointer, padding ... synthesized” must acknowledge explicit provenance2/3 assumptions. Preserve the distinction between default entry points and independent internal flags; the existing legacy/strict default is correct. Historical checkpoint documents should remain historical, with a link to this audit rather than rewritten evidence. The original generator does not itself verify holes; the Solidity counterpart adds the coverage rejection.
- Preserve the conditional Episode pointer predicate in acceptance reporting. Before claiming additional full-map native equality, capture actual native allocation identities and all relevant sampled pointer guards in that scenario. Do not relabel the current component proof or successful EVM rendering as full native frame equivalence.
- Keep original-C UB, deliberate host adaptations, and sanitizer exclusions visible. Known failures remain failures; no golden/expected-byte rewrite is justified by this audit.

**Can defer:** unify profile manifests/constructor helpers, automatically verify compiler identity in the small component generators and layout exporter, add per-sample provenance telemetry to future native/EVM comparison runners, and evaluate a sparse write journal only if an authorized supported scenario needs currently unknown mutable/history bytes. Initial-free tag/ID, known null/unowned low-pointer bytes, explicit actor memset regions and preserved immutable freed data are possible future classes, but require correct lifetime/overwrite handling; current unknown classification is conservative rather than incorrect. Long-lived historical-record growth/resource costs were not measured here.

**Do not change:** pinned original C, existing fixtures, Solidity compiler/viaIR/hardfork/budgets, the already needed LP64 adapters, original draw/clip/RNG/allocation order, or strict rejection merely to make more frames render. Do not universalize low pointers, reseed reused payloads as virgin, or remove composite hole checks. Retain the hybrid and its provenance separation.

## 7. Literal compiler/link/environment inventory

This appendix is **source-inspected configuration**, not a claim that all historical harnesses were rebuilt during this audit. The seven freshly executed experiment commands and four layout compilation commands are recorded literally in the audit JSON manifests, including absolute paths. In the expansions below `<repo>` is this checkout and `<build>` is the runner's temporary/output directory; `O` is `O0` or `O2`. There are no omitted policy flags inside `B`, `H`, `G` or `Z`:

```text
B(O) = -std=c99 -O -fwrapv -fno-strict-aliasing -ffp-contract=off -fno-fast-math

H = -DNORMALUNIX
    -include stdint.h -include stddef.h -include stdlib.h
    -include string.h -include strings.h -include alloca.h
    -include <repo>/tools/reference/renderer/trace.h
    -Wno-incompatible-pointer-types -Wno-implicit-function-declaration
    -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast

G(O) = B(O) -fsigned-char H -include <build>/gameplay-observe.h

S = -fsanitize=address,undefined -fno-sanitize-recover=all

Z(O) = -std=gnu11 -fsigned-char -fwrapv -fno-strict-aliasing
       -ffp-contract=off -fno-fast-math -O
```

Here the token `-O` means `-O0` or `-O2`, not an additional literal optimization flag. Native diagnostic `strict=True` removes `-fwrapv`; it does not otherwise reset the options. The following complete option compositions supplement source-file arguments and the final `-o <binary>`:

| Harness family | Compile/link options and profile alterations |
|---|---|
| Foundation | `B(O) -I<repo>/tools/reference -I<original-source>`; sanitizer build uses `B(O2)` without wrapv, plus `-fsanitize=undefined,float-cast-overflow -fno-sanitize-recover=all`; no explicit linker options |
| Phase2 data | `B(O) -I<repo>/tools/reference/phase2_data`; mixed sanitizer adds `-fsanitize=undefined -fno-sanitize=shift -fno-sanitize-recover=all`; clip-only sanitizer removes wrapv and uses `-fsanitize=undefined -fno-sanitize-recover=all` without shift suppression; no explicit linker options |
| Static renderer | `B(O) H -I<build> -Wl,-dead_strip`; sanitized adds `S`; source-file list is `renderer.UNITS`, generated map_loader/actions and renderer host |
| Gameplay | `G(O) -I<build> -Wl,-dead_strip`; sanitized adds `S`; compile actual `renderer.UNITS + PUNITS`, generated game_functions and gameplay host |
| Zone lifecycle / Episode startup | `G(O) -include <build>/zone-observe.h -I<build> -Wl,-dead_strip`; sanitized adds `S`; Episode compiles the prepared original units and its generated episode-host/game_functions using those options, with no extra sanitizer exclusions |
| UI | `G(O) -ffunction-sections -fdata-sections -I<build> -I<repo>/tools/reference/gameplay -Wl,-dead_strip`; adds original ST/HU/video units; sanitized adds `-fno-sanitize=array-bounds` after `S` |
| Input runtime | `G(O) -Wno-implicit-int -ffunction-sections -fdata-sections -I<build> -I<repo>/tools/reference/gameplay -Wl,-dead_strip`; sanitized adds `S -fno-sanitize=array-bounds`; source list and final link are explicit in `build_native` |
| Allocator/backing/blood components | `Z(O) -I <original-source> -I <build>`; sanitized adds `-fsanitize=address,undefined -fno-omit-frame-pointer`, with no compile-time no-recover flag; no explicit linker options |
| Episode pointer component | `-std=gnu11 -fsigned-char -fwrapv -fno-strict-aliasing -O0` or `-O2`, plus `-I<original-source> -I<build>`; sanitized O2 adds `-fsanitize=address,undefined`; no frame-pointer/no-recover/floating flags or explicit linker options |
| Native layout exporter | `-std=c11 -I<build> -I<original-source>`; no explicit optimization, sanitizer or link options; audit's fresh layout variant needs only `-I<original-source>` |
| New audit probe | `Z(O)` plus the exact per-profile additions in experiment.json; default supported sanitized variant adds `-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer`; auto-init adds `-ftrivial-auto-var-init=zero`; no-wrapv adds `-fno-wrapv`; unadapted-align4 sanitized omits frame-pointer flag. No explicit link options |

The family sources linked in §1 provide the argument ordering, translation-unit lists and extraction/adaptation machinery. These templates describe options; the fresh manifests preserve actual argument arrays, source hashes and executable hashes. No `-m32`, packing flag, fast-math, fixed-address link flag or ASLR-disabling action was added.

| Runner | Explicit environment supplied by source |
|---|---|
| Renderer/gameplay/zone verification | Inherits `os.environ`; overrides `ASAN_OPTIONS=detect_leaks=0`; selected comparison rows set `DOOM_ORACLE_ALLOCATION_FILL=0` or `0xa5` |
| UI/input verification | Inherits environment; overrides `ASAN_OPTIONS=detect_leaks=0:halt_on_error=1`, `UBSAN_OPTIONS=halt_on_error=1`, and per-row allocation fill0/0xa5 |
| Episode startup / pointer component | Inherits environment; overrides only `ASAN_OPTIONS=detect_leaks=0` |
| Allocator/backing/blood/data components | Subprocess environment is inherited unless the caller changes it; no explicit sanitizer environment in these runners |
| New audit | Removes inherited keys starting `ASAN_`, `UBSAN_`, `Malloc`, `DYLD_`, `DOOM_`; sets `ASAN_OPTIONS=detect_leaks=0`, `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=0`; does not alter process ASLR |

The Episode startup manifest's “no fresh-allocation zero fill” description therefore assumes `DOOM_ORACLE_ALLOCATION_FILL` was absent from the inherited environment. Its runner does not unset that variable. This is a concrete **reproducibility limitation**, not evidence the preserved startup fixture was generated incorrectly. Future profile recording should explicitly capture or sanitize these relevant variables, rather than infer their values from a runner's default behavior. This audit does not recover missing historical environments or silently change any runner.

## 8. Reproduction, verification boundaries and handoff

Run from the assigned repository with the pinned Apple toolchain:

```sh
python3 tools/reference/native_memory_audit/check.py
python3 tools/reference/native_memory_audit/run.py --output /private/tmp/doom-native-memory-audit-replay
python3 tools/reference/native_memory_audit/inventory.py --output /private/tmp/doom-native-memory-audit-replay
python3 tools/reference/native_memory_audit/check.py --output /private/tmp/doom-native-memory-audit-replay
python3 tools/zone/generate-layout.py --check
```

Use a fresh output directory to preserve this checkpoint. Repeated raw addresses, malloc bytes, executable hashes and temporary-path-containing compiler diagnostics are not expected to match byte-for-byte. The runner/checker assert the relationships that are expected, preserving all other bytes as observations. Temporary native sources/binaries are deleted by the runner; exact generating code, commands and hashes remain. No historical fixture runner is invoked in write mode.

[check-result.json](../artifacts/phase4/native-memory-audit/check-result.json) records 105 current source bindings,63 successful process observations,3 expected failures,963 texture records / 338 nonempty composites, the exact record 76 binding and nine retained blood observations. The checker is read-only. The audit adds no new Forge/EVM/browser acceptance; previously reported239 Forge/58Node results belong to the preceding feature handoff. Fresh native probes and source/evidence/link checks are proportionate to this documentation/test-only audit under Phase4 policy§5.

Owned deliverables: this report; `tools/reference/native_memory_audit/{probe.c,run.py,inventory.py,check.py}`; `artifacts/phase4/native-memory-audit/` evidence. No shared ledger edit, production/original-source edit, fixture change, runtime, branch/worktree operation, commit, merge or push was performed by this audit agent. The coordinating agent reviewed the exact diff and records the documentation/test-only Gitmoji commit on the existing feature branch; its exact SHA is supplied in the final handoff. No tokens, dollar cost, or hidden model counters are estimated; model/reasoning selection is the parent-requested GPT-6 Astra maximum profile, not separately measured runtime telemetry.

Parent review independently reran the same matrix: another 66 processes, again 63 successes and 3 expected align4 failures, plus layout/source/fixture checks. This corroborates the focused observations without expanding their coverage. See [root-review.json](../artifacts/phase4/native-memory-audit/root-review.json) and its hash-bound replay archive; original audit matrix counts above are not doubled into independent cases.

Measured audit-agent endpoint: **2026-10-10T17:18:35.566545+00:00**; start/end wall-clock interval **842.567s**. Native matrix time is separately recorded as 2.803 s, inventory/check/review time is included only in this wall-clock interval. No CPU-time or token-usage estimate is made.

Coordinator verification includes a separate replay, read-only evidence checks, local-link validation, and a baseline diff confirming unchanged production, original C, accepted fixtures and compiler configuration. The separately captured [goal usage snapshot](../artifacts/phase4/native-memory-audit/goal-usage.json) records available counters without estimating model-specific usage or cost. It precedes final publication and is not the final token total.
