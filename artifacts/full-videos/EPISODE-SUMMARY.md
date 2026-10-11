# Nine complete Ultimate DOOM Episode One presentations

All nine original speedruns reach their genuine exits. All gameplay, original
Status Bar/HUD, Intermission/finale and source-derived screen melt pixels are
computed inside EVM. Output is silent 35 FPS H.264, 1280×960, square-pixel 4:3.
Original palette decoding/scaling/encoding are the only host pixel operations.
Commercial WAD/frames/media and full receipts remain local; hashes, provenance,
structured telemetry and reproduction tools are retained in Git.

Aggregate final recording gas: **18,947,598,824,099** across
**39,472 successful mined transactions**.
Gameplay: **14,475 tics** and
**14,484 matching canonical snapshots**.
Final encoded EVM frames: **18,175**.
Video duration summed across all nine files: **519.285714s**.
Finite native-equal indexed frames: **18,173**.
Direct experimental virtual-address sample uses: **25**.
These totals exclude failed attempts and separate diagnostic/rollback transactions.

| Map | Gameplay tics | Gameplay seconds | Video frames | Video seconds | Gas | Successful tx | Render RPC FPS | Finite native-equal frames | Virtual frames / uses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| E1M1 | 316 | 9.029 | 547 | 15.629 | 324,602,338,892 | 1,621 | 1.868 | 547 | 0 / 0 |
| E1M2 | 798 | 22.800 | 1029 | 29.400 | 917,395,666,205 | 2,585 | 1.254 | 1029 | 0 / 0 |
| E1M3 | 1291 | 36.886 | 1522 | 43.486 | 1,728,806,988,621 | 3,571 | 1.057 | 1521 | 2 / 4 |
| E1M4 | 767 | 21.914 | 1003 | 28.657 | 811,950,237,036 | 2,528 | 1.397 | 1003 | 0 / 0 |
| E1M5 | 2110 | 60.286 | 2346 | 67.029 | 2,635,722,517,898 | 5,214 | 1.002 | 2345 | 2 / 8 |
| E1M6 | 3385 | 96.714 | 3619 | 103.400 | 5,459,324,203,074 | 7,762 | 0.792 | 3619 | 5 / 8 |
| E1M7 | 2572 | 73.486 | 2808 | 80.229 | 3,305,344,543,682 | 6,138 | 0.992 | 2808 | 1 / 3 |
| E1M8 | 1638 | 46.800 | 3467 | 99.057 | 2,068,482,084,762 | 5,863 | 1.623 | 3467 | 1 / 2 |
| E1M9 | 1598 | 45.657 | 1834 | 52.400 | 1,695,970,243,929 | 4,190 | 1.254 | 1834 | 0 / 0 |

Each map's JSON contains original tape identity, genuine authoritative kill/item/
secret/time/par statistics, mutually exclusive frame counters, overlapping Status
Bar coverage, gas min/mean/median/max, actual operation-category receipts,
maximum transaction gas, measured failures, UTC bounds, setup/render/RPC timing,
throughput and computation/video ratios, finite native comparison coverage,
virtual provenance and final-frame differences, Anvil configuration, frozen source/
ABI/IWAD/input hashes, media paths and verification bindings.

Render RPC FPS divides actual emitted frames by the measured transaction intervals
that emit them. Those intervals include localhost transport, mining and polling;
they are not EVM-only CPU time or realtime network performance. UTC elapsed
windows include resumed downtime where applicable. Exact recorded session
windows and matching inherited-prefix session bounds are summed when available;
full inherited-prefix wall bounds remain unavailable for the checkpoint-forked
E1M1 pilot. Its measured receipt RPC time is retained without a wall-time estimate. End-to-end per-map pipeline
stage timings are reported separately. Concurrent per-map durations must not be
summed and relabeled episode wall time. No missing cost or timing is estimated.
Summed measured transaction RPC processing: **18,795.220818 seconds**.
Summed processing/video-duration ratio: **36.194373 times**.
This is measured transaction work summed across maps, not concurrent episode wall time.
World rendering, Status Bar and HUD execute in one capture transaction and have
no separately measured gas attribution. Gameplay advance also includes ST/HU
tickers and observations. Pure eth_call gas/CPU subdivisions are unavailable. Optional subdivision remains unavailable.

The deterministic display clock uses one tic per original blocking wipe step;
no gameplay or input command advances during the wipe. Authentic tape files are
preserved; final recordings consume their exact gameplay prefixes and separate
authorized post-exit input appendices. Original WI button-edge acceleration
reveals the final statistics, holds 105 frames, then briefly draws original
Entering/NoState(cnt1). The endpoint is a recording choice; no next level loads.
E1M8 uses zero-input original finale timing and 105 final art frames.
E1M8 bypasses Intermission and includes the original forced finale-art melt.
E1M9 marks didsecret and points to E1M4. No next-map gameplay is fabricated.

Native references use unchanged original C functions with the established
consistent borrowed immutable UI-resource/LP64/initial-zone profile, original
differential ST/HU display history and temporary gameplay render chronology.
Previous source framebuffers are independently native-generated. Old mixed
ST_lib-cache and forced-full-refresh reference failures remain preserved. Canonical gameplay snapshots keep historical miscellaneous
RNG counters; original ST/WI/wipe use a separately retained presentation RNG.
Gameplay P_Random and all original command bytes remain unchanged. Finite native
pixel equality does not make virtual zone/owner pointer bytes universal native
values. Their explicit provenance categories remain experimental and RESTRICT.
Whole gameplay-frame equality counts use the declared native O2 reference;
common native pixels outside explicit virtual destinations are checked across
O0/O2/sanitizer profiles. All UI/melt/finale references agree across those profiles.
E1M3/E1M5 use the preserved supported initial-zero-zone native domain; their
adversarial allocation-fill failures remain failures and are retained separately.
The archive's original recording IWAD identity is unavailable; these replays are
verified against the authenticated compatible classic Ultimate DOOM IWAD identified below.
H.264 is lossy; indexed8 comparisons establish pixel equality before encoding.

The original baseline recordings, saved frames, input archives and provenance
are preserved and checked read-only. Failed pilot/earlier attempts remain separate.
Production/browser integration and the full historical Phase 0–4 acceptance suite
are outside this feature verification. Reproduce using the suite README and the
per-map manifest's exact frozen source/resource/configuration bindings.

## Gameplay identities and authoritative statistics


| Map | Author / original tape | Kills / total | Items / total | Secrets / total | Time tics / whole seconds | Par seconds |
| --- | --- | --- | --- | --- | --- | --- |
| E1M1 | aconfusedhuman / e1m1-903.lmp | 3 / 29 | 2 / 38 | 0 / 3 | 316 / 9 | 30 |
| E1M2 | trioct / e1m2-2280.lmp | 7 / 79 | 0 / 42 | 0 / 6 | 798 / 22 | 75 |
| E1M3 | Jonathan Rimmer / e1m3-036/e1m3-036.lmp | 46 / 131 | 10 / 95 | 0 / 7 | 1291 / 36 | 120 |
| E1M4 | izzybell / e1m4-0021.lmp | 0 / 85 | 5 / 45 | 0 / 3 | 767 / 21 | 90 |
| E1M5 | trioct / e1m5-100.lmp | 60 / 131 | 6 / 29 | 1 / 9 | 2110 / 60 | 165 |
| E1M6 | ShadowCaco33 / e1m6-0136.lmp | 66 / 177 | 24 / 113 | 2 / 4 | 3385 / 96 | 180 |
| E1M7 | mhrz / e1m7-113.lmp | 63 / 150 | 22 / 84 | 1 / 4 | 2572 / 73 | 180 |
| E1M8 | Sedlo / e1m8-046.lmp | 2 / 41 | 0 / 3 | 0 / 1 | 1638 / 46 | 30 (catalog only; no WI) |
| E1M9 | ShadowCaco33 / e1m9-0045.lmp | 39 / 103 | 4 / 43 | 0 / 2 | 1598 / 45 | 165 |

## Frame accounting


| Map | Gameplay | Complete Status Bar coverage | Title | Menu | Melt | Intermission | Finale | Total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1M1 | 315 | 317 | 35 | 0 | 80 | 117 | 0 | 547 |
| E1M2 | 797 | 799 | 35 | 0 | 80 | 117 | 0 | 1029 |
| E1M3 | 1290 | 1292 | 35 | 0 | 80 | 117 | 0 | 1522 |
| E1M4 | 766 | 768 | 35 | 0 | 85 | 117 | 0 | 1003 |
| E1M5 | 2109 | 2111 | 35 | 0 | 85 | 117 | 0 | 2346 |
| E1M6 | 3384 | 3386 | 35 | 0 | 83 | 117 | 0 | 3619 |
| E1M7 | 2571 | 2573 | 35 | 0 | 85 | 117 | 0 | 2808 |
| E1M8 | 1637 | 1639 | 35 | 0 | 121 | 0 | 1674 | 3467 |
| E1M9 | 1597 | 1599 | 35 | 0 | 85 | 117 | 0 | 1834 |

Status Bar coverage overlaps gameplay and melt; it is not added to the total.

## Measured processing time


| Map | Active recorded wall seconds | Elapsed window seconds | Transaction RPC seconds | Setup RPC seconds | Render RPC seconds | Active wall / video ratio |
| --- | --- | --- | --- | --- | --- | --- |
| E1M1 | Unavailable | 26.015 | 348.195 | 21.664 | 292.822 | Unavailable |
| E1M2 | 996.467 | 235.080 | 954.943 | 22.072 | 820.696 | 33.893 |
| E1M3 | 1,695.605 | 1,695.605 | 1,639.478 | 21.583 | 1,440.385 | 38.992 |
| E1M4 | 861.557 | 861.557 | 829.695 | 21.273 | 718.019 | 30.064 |
| E1M5 | 2,731.349 | 11,444.465 | 2,647.545 | 21.865 | 2,340.370 | 40.749 |
| E1M6 | 5,323.219 | 13,317.181 | 5,155.506 | 22.676 | 4,570.244 | 51.482 |
| E1M7 | 3,322.452 | 3,322.452 | 3,216.130 | 21.750 | 2,830.233 | 41.412 |
| E1M8 | 2,438.245 | 2,438.245 | 2,338.781 | 21.246 | 2,135.673 | 24.615 |
| E1M9 | 1,720.751 | 1,720.751 | 1,664.949 | 23.589 | 1,462.460 | 32.839 |

## Gas distributions


| Map | Transaction gas min / mean / median / max | Rendered-frame transaction gas min / mean / median / max |
| --- | --- | --- |
| E1M1 | 239,560 / 200,248,204 / 39,473,455 / 1,565,582,432 | 20,129,268 / 506,561,355 / 618,729,947 / 1,565,582,432 |
| E1M2 | 239,560 / 354,891,941 / 197,371,755 / 2,098,832,052 | 20,129,268 / 729,394,794 / 742,236,808 / 2,098,832,052 |
| E1M3 | 239,560 / 484,124,052 / 248,569,468 / 4,247,280,676 | 20,129,268 / 933,587,222 / 930,857,020 / 4,247,280,676 |
| E1M4 | 239,560 / 321,182,847 / 171,688,534 / 2,220,805,868 | 20,129,268 / 673,508,429 / 692,347,090 / 2,220,805,868 |
| E1M5 | 239,560 / 505,508,730 / 227,442,078 / 5,555,860,946 | 20,129,268 / 938,743,940 / 784,974,632 / 5,555,860,946 |
| E1M6 | 239,560 / 703,339,887 / 298,521,374 / 4,663,562,559 | 20,129,268 / 1,234,315,420 / 1,121,758,998 / 4,663,562,559 |
| E1M7 | 239,560 / 538,505,139 / 246,438,896 / 5,045,698,007 | 20,129,268 / 963,173,317 / 837,056,024 / 5,045,698,007 |
| E1M8 | 239,560 / 352,802,675 / 137,362,738 / 2,080,193,509 | 20,129,268 / 526,591,528 / 137,362,738 / 2,080,193,509 |
| E1M9 | 239,560 / 404,766,168 / 177,531,148 / 3,483,662,641 | 20,129,268 / 770,316,931 / 747,088,364 / 3,483,662,641 |

Gas is consumed in actual local mined transactions. Aggregate successful transaction gas/frame distributions and operation-category totals are in episode-telemetry.json. Per-rendered-frame gas is the emitting transaction cost; allocation/setup and separate gameplay advances are accounted separately.

## Failures and recovery


| Map | Failed final mined transactions | Manual checkpoint resumes | Observed retained final-directory log errors |
| --- | --- | --- | --- |
| E1M1 | 0 | 0 | 0 |
| E1M2 | 0 | 0 | 1 |
| E1M3 | 0 | 0 | 1 |
| E1M4 | 0 | 0 | 0 |
| E1M5 | 0 | 1 | 2 |
| E1M6 | 0 | 1 | 2 |
| E1M7 | 0 | 0 | 0 |
| E1M8 | 0 | 0 | 0 |
| E1M9 | 0 | 0 | 0 |

Log errors include native comparison assertions, requested recoverable stops and refusal of an occupied verification port. Their classifications and line/hash bindings are preserved in attempt-inventory.json. These do not indicate failed final gameplay transactions. Automatic transaction resubmission is disabled; receipt polling does not resubmit. Earlier failed attempts retain separate receipt gas and lineage. Their costs are not summed because checkpoints share inherited receipts; unreceipted failures have unavailable gas.

## Final MP4 paths and verification

- [E1M1 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M1/pilot-short-v2/ultimate-e1m1-complete.mp4); SHA256 `4a8be58e4d401e6fd628449e2b99874d359e13c213eb3153bab7e17b5566a3ae`; final indexed framebuffer differences 0.

- [E1M2 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M2/complete-short-v1/ultimate-e1m2-complete.mp4); SHA256 `4bb78a8c1e3481d955dcf1f34ba1a0ffd2f02feed7d972deaccfa57ee99028d4`; final indexed framebuffer differences 0.

- [E1M3 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M3/complete-short-v1/ultimate-e1m3-complete.mp4); SHA256 `8d100d2044ff1fd55fd7034f5583351fab37f49a34ce4e755c39c3f5b1677c9a`; final indexed framebuffer differences 0.

- [E1M4 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M4/complete-short-v1/ultimate-e1m4-complete.mp4); SHA256 `271ff48062705ae1819029407fefd119a5f5e584412bf03f3ec6b05cb0c920a3`; final indexed framebuffer differences 0.

- [E1M5 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M5/complete-short-v1/ultimate-e1m5-complete.mp4); SHA256 `2ba361f008a4059155e6c0f59e3c197738f89944b77a50ccf2da6f073459d211`; final indexed framebuffer differences 0.

- [E1M6 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M6/complete-short-v1/ultimate-e1m6-complete.mp4); SHA256 `8bc1eb482650034a7a3f277fcba306612db0cc392cb37a78085e06b20638d9ea`; final indexed framebuffer differences 0.

- [E1M7 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M7/complete-short-v1/ultimate-e1m7-complete.mp4); SHA256 `d9302f8b563dcffdfe4bcddaabf71c8a5da1db49dbc9f2b22a35598db910a2ef`; final indexed framebuffer differences 0.

- [E1M8 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M8/complete-short-v1/ultimate-e1m8-complete.mp4); SHA256 `bdfe6145784525ad2d58dc1b36504dee4b2e104f7ea09376b7c392f32fd485d2`; final indexed framebuffer differences 0.

- [E1M9 MP4](/Users/eduard/sandbox/doom-evm-full-videos/artifacts/local/full-videos/E1M9/complete-short-v1/ultimate-e1m9-complete.mp4); SHA256 `ba096c3a7a3ae1a01b6e6f6609f16e03ec399c554eee88bf28ef864a18164958`; final indexed framebuffer differences 0.

## Preserved long pilot versus abbreviated pilot


| Metric | Long pilot | Abbreviated pilot |
| --- | --- | --- |
| Total frames | 3498 | 547 |
| Intermission frames | 3068 | 117 |
| Melt frames | 80 | 80 |
| Gas consumed | 689031769853 | 324602338892 |
| Successful transactions | 4572 | 1621 |
| Measured transaction RPC seconds | 858.1894692930025 | 348.1945279180001 |

Saved 2,951 frames, 364,429,430,961 gas and 509.994941 measured RPC seconds. The old pilot's full recorder wall time is 954.584s; the new appended-UI session is 26.015s. The new full inherited-prefix wall time is unavailable, so these two session windows are not compared as equivalent totals. Both full melts and all 317 original gameplay snapshots remain unchanged. The historical 3498-frame MP4 remains at `artifacts/local/full-videos/E1M1/pilot-v2/ultimate-e1m1-complete.mp4`.

The original Entering endpoint was explicitly read back as WI state=-1,cnt=1,worldDoneRequested=false. A small recorder-only metadata copy fixes the later guard omission but is compiled/source-audited only. Neither G_WorldDone execution nor subsequent level startup is claimed verified. Failed short-pilot, native mixed-cache and full-refresh reference attempts remain diagnostic evidence.

## Environment and source identities

Measured host: Apple M3 Pro, 38,654,705,664 physical RAM bytes, arm64, macOS 15.7.9 (24G830). Anvil/Forge 1.8.5, solc 0.8.37+commit.f401782d, viaIR, optimizer 200, Cancun. Each owned Anvil uses 10,000,000,000 gas and 1,073,741,824 EVM memory bytes, disables the code-size and RPC request-body limits, and retains two history blocks. Per-request timeout 300s; state dump 900s; receipt polling has no separate aggregate deadline. At most two recording jobs run concurrently. Tool version output and full arguments are preserved in environment.json and per-map telemetry.

Authenticated IWAD SHA256: `6fdf361847b46228cfebd9f3af09cd844282ac75f3edbb61ca4cb27103ce2e7f`; original C revision: `a77dfb96cb91780ca334d0d4cfd86957558007e0`. The feature HEAD at execution is paired with exact generated source hashes, ABI hash, deployed runtime hash and resource bundle identity; HEAD alone does not identify an observation clone or an uncommitted recorder helper.


| Map | Recorded feature HEAD | Original input tape SHA256 |
| --- | --- | --- |
| E1M1 | c763e58886c899f5138563ae9201315ad5bdcf0a | e5766abc098faf496c2b7787668e4c21c0a4ebf819c7667ce59c4ca14dc39288 |
| E1M2 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | 1210cbccd5148091f438d9fb5f8f763b0b49cdb1e3870380521c0b2632fbc15f |
| E1M3 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | d91a896d529672e5bbc011b7607de75308c183643ee204d722e8704e348a9f5e |
| E1M4 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | 1f5427b2776aa7deb83716350eb6d252e4953895aa338c239bf62eeac5d67fdf |
| E1M5 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | 4a3ffd0a1f92ac2980e9c3b5aafde01a6ec2fb4eaca0fdde61ab85d51e1ea48e |
| E1M6 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | fa51135c2bee9b4c82c1b0390c6e29755b347237c981b911cef044e4b01e1ea6 |
| E1M7 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | 182931b0afdcace7dffe66c74bdcd546e6e110eed95a725ce79dc7dd4ce5041e |
| E1M8 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | a47622d63d3b797280842c86b858cf80a7d85b7b1df03882db08f5f16fb261ef |
| E1M9 | 94a8e3909f81cd1d891f99eed1b0a0cff7b4d0f8 | ae640d1a17919e24983afd9d191d75502f0f745b89a52fff808ee41a2761bfb1 |

Host monitoring summary is in host-summary.json: sampled RSS/disk/swap observations are distinguished from guaranteed peaks and exclusive resource attribution. Source allocations, gameplay snapshots and commercial pixel buffers remain unchanged by telemetry collection.
