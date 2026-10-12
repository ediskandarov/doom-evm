# Worktree/session coverage

This is a coverage view of the 49 registered pre-audit worktrees. Local parent directories are replaced by `$WORKTREES`; the original checkout is `$REPO`. Branches are observed at the audit baseline, not assumed to have remained unchanged throughout development.

**Exclusive** is usage assigned to that worktree/goal. **Shared** is the entire measured session bucket spanning several worktrees; it is repeated for visibility and is **not additive across rows**. A shared bucket has high project/session confidence but an unresolved directory split. “No separate attribution” is not proven zero consumption.

The [complete CSV](../../artifacts/usage/final/worktree_coverage.csv) contains full session IDs, agent identities, workstream labels, exact UTC bounds and ambiguity notes. [Session totals](../../artifacts/usage/final/sessions.csv) and [additive worktree groups](../../artifacts/usage/final/by_worktree_group.csv) reconcile to the [final report](CODEX-USAGE-FINAL.md).

| Worktree alias | Branch | Session IDs (abbreviated) | Exclusive tokens | Shared tokens (nonadditive) | First → last usage UTC | Confidence |
|---|---|---|---:|---:|---|---|
| `$REPO` | `main` | 01a11fdf…6b9c, 01a12100…dce2, 01a12100…e57d, 01a12103…4475, 01a12245…7933, 01a12437…7ba9, 01a12469…521d, 01a124c9…b90d, 01a124ce…8171, 01a124da…3a39, 01a12538…2e8b, 01a126b1…df18, 01a12743…7de2, 01a12a5f…a626, 01a12ab7…239a, 01a12bd1…3685, 01a12c8a…d998 | 553,353,162 | 0 | 10-09 09:06 → 10-12 06:18 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-assets` | `phase1/assets` | 01a12041…b872 | 2,038,766 | 0 | 10-09 10:41 → 10-09 10:57 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-episode-startup` | `feat/phase4-episode-startup` | 01a1258d…2547 | 0 | 11,370,515 | 10-10 11:23 → 10-10 13:08 | shared-session-unsplit |
| `$WORKTREES/doom-evm-input-runtime` | `feat/phase4-input-runtime` | 01a1258d…bab5 | 0 | 13,695,050 | 10-10 11:23 → 10-10 13:43 | shared-session-unsplit |
| `$WORKTREES/doom-evm-numeric` | `phase1/numeric` | 01a12040…5219 | 1,294,088 | 0 | 10-09 10:41 → 10-09 10:57 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-p2-bsp` | `phase2/bsp` | 01a1205f…104d | 0 | 21,110,260 | 10-09 11:14 → 10-09 12:51 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-data` | `phase2/data` | 01a1205f…fad0 | 0 | 24,042,591 | 10-09 11:15 → 10-09 12:53 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-draw` | `phase2/draw` | 01a1205f…7c66 | 0 | 15,642,123 | 10-09 11:15 → 10-09 13:12 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-e2e` | `phase2/e2e` | 01a1205f…104d, 01a1205f…fad0, 01a1205f…7c66 | 0 | 60,794,974 | 10-09 11:14 → 10-09 13:12 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-gates` | `phase2/gates` | 01a1205f…104d | 0 | 21,110,260 | 10-09 11:14 → 10-09 12:51 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-geometry` | `phase2/geometry` | 01a1205f…104d | 0 | 21,110,260 | 10-09 11:14 → 10-09 12:51 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-planes` | `phase2/planes` | 01a1205f…104d | 0 | 21,110,260 | 10-09 11:14 → 10-09 12:51 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-segs` | `phase2/segs` | 01a1205f…7c66 | 0 | 15,642,123 | 10-09 11:15 → 10-09 13:12 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-source` | `phase2/source` | 01a1205f…fad0 | 0 | 24,042,591 | 10-09 11:15 → 10-09 12:53 | shared-session-unsplit |
| `$WORKTREES/doom-evm-p2-sprites` | `phase2/sprites` | 01a1205f…fad0 | 0 | 24,042,591 | 10-09 11:15 → 10-09 12:53 | shared-session-unsplit |
| `$WORKTREES/doom-evm-public-release` | `feat/public-release` | 01a12ec8…af28, 01a12ec8…af56, 01a12ee6…a98d | 15,129,460 | 0 | 10-12 06:25 → 10-12 08:01 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-reference` | `phase1/reference` | 01a12040…fa23 | 3,818,991 | 0 | 10-09 10:41 → 10-09 11:03 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-schemas` | `phase0/schemas` | 01a11ff3…6e2d | 1,607,017 | 0 | 10-09 09:16 → 10-09 09:45 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-stack` | `phase0/stack` | 01a11ff3…6778 | 1,328,092 | 0 | 10-09 09:16 → 10-09 09:43 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-transport` | `phase0/transport` | 01a11ff3…a875 | 1,856,294 | 0 | 10-09 09:16 → 10-09 09:47 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-automap` | `feat/phase4-automap` | 01a12544…f6b1 | 6,410,950 | 0 | 10-10 10:03 → 10-10 10:41 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-browser-deploy` | `feat/browser-deploy-core` | none separately attributed | 0 | 0 | unavailable | no-separate-session-attribution |
| `$WORKTREES/doom-evm-browser-deployment` | `feat/browser-deployment` | 01a12a40…4e84 | 5,649,252 | 0 | 10-11 09:18 → 10-11 09:44 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-cheats` | `feat/phase4-cheats` | 01a12544…9bd4 | 4,787,057 | 0 | 10-10 10:03 → 10-10 10:40 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-discovery-episode` | `detached` | 01a1258d…2547 | 0 | 11,370,515 | 10-10 11:23 → 10-10 13:08 | shared-session-unsplit |
| `$WORKTREES/doom-evm-discovery-input` | `detached` | 01a1258d…bab5 | 0 | 13,695,050 | 10-10 11:23 → 10-10 13:43 | shared-session-unsplit |
| `$WORKTREES/doom-evm-discovery-intermission` | `feat/phase4-intermission` | 01a1258d…d89f | 12,485,777 | 0 | 10-10 11:23 → 10-10 13:26 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-doom2-browser` | `feat/doom2-browser` | 01a12a74…56be | 20,385,492 | 0 | 10-11 10:14 → 10-11 11:16 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-episode-completion` | `feat/phase4-episode-completion` | 01a12649…0adb, 01a12659…d8d4, 01a126a1…da70, 01a126c5…5031, 01a126d3…cb98 | 37,169,776 | 0 | 10-10 14:49 → 10-10 17:20 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-full-videos` | `feat/full-speedrun-videos` | 01a12a41…bce2 | 62,396,212 | 0 | 10-11 09:18 → 10-11 16:41 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-game-launcher` | `feat/browser-game-launcher` | none separately attributed | 0 | 0 | unavailable | no-separate-session-attribution |
| `$WORKTREES/doom-evm-gameflow` | `feat/phase4-gameflow` | 01a124e5…87b7 | 5,561,638 | 0 | 10-10 08:20 → 10-10 09:42 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-hud` | `feat/phase4-hud` | 01a124e6…0eb0 | 3,188,285 | 0 | 10-10 08:20 → 10-10 09:43 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-memory-audit` | `audit/phase4-memory` | 01a124ca…943c | 6,366,542 | 0 | 10-10 07:51 → 10-10 09:47 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-menu` | `feat/evm-menu` | 01a126e7…ddc4 | 16,687,146 | 0 | 10-10 17:43 → 10-10 19:15 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-multimap` | `feat/phase4-multimap` | 01a12544…2bd5 | 4,810,895 | 0 | 10-10 10:04 → 10-10 10:38 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-options` | `feat/options-menu` | 01a12b83…3bc8 | 20,320,811 | 0 | 10-11 15:15 → 10-11 16:27 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-palette` | `feat/palette-effects` | 01a12b82…0c54 | 3,595,308 | 0 | 10-11 15:08 → 10-11 15:26 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-playground` | `detached` | none separately attributed | 0 | 0 | unavailable | no-separate-session-attribution |
| `$WORKTREES/doom-evm-respawn` | `feat/death-respawn` | 01a12bc0…0ea4 | 34,068,806 | 0 | 10-11 16:17 → 10-11 19:36 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-save-load` | `feat/save-load` | 01a12bc1…5a5c | 36,519,254 | 0 | 10-11 16:17 → 10-12 04:50 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-speedrun` | `feat/phase4-speedrun-e1m1` | 01a1264f…6f92, 01a12679…2bb1 | 10,171,969 | 0 | 10-10 14:56 → 10-10 16:01 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-speedrun-debug` | `fix/speedrun-tic52` | 01a126d3…c8da | 9,983,538 | 0 | 10-10 17:20 → 10-10 17:51 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-speedruns-vptr` | `feat/episode-speedruns-vptr` | 01a12745…8dc2, 01a12747…3f3e, 01a127b8…811e, 01a1295d…e82c, 01a129d1…69a4 | 0 | 84,569,638 | 10-10 19:24 → 10-11 07:50 | shared-session-unsplit |
| `$WORKTREES/doom-evm-statusbar` | `feat/phase4-statusbar` | 01a124e5…c7c8 | 6,009,798 | 0 | 10-10 08:19 → 10-10 09:52 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-ui-integration` | `feat/phase4-ui-integration` | 01a12588…0f2f | 9,806,357 | 0 | 10-10 11:18 → 10-10 12:01 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-ultimate-browser` | `feat/ultimate-browser` | 01a12a74…4660 | 12,043,434 | 0 | 10-11 10:14 → 10-11 11:03 | reviewed-or-metadata |
| `$WORKTREES/doom-evm-ultimate-speedruns` | `feat/ultimate-episode-speedruns` | 01a12745…8dc2, 01a12747…3f3e, 01a127b8…811e, 01a1295d…e82c, 01a129d1…69a4 | 0 | 84,569,638 | 10-10 19:24 → 10-11 07:50 | shared-session-unsplit |
| `$WORKTREES/doom-evm-virtual-memory` | `experiment/virtual-pointer-memory` | 01a126fd…f235 | 8,513,256 | 0 | 10-10 18:05 → 10-10 18:39 | reviewed-or-metadata |

The audit worktree itself is excluded. Root metadata often retained `doom-evm` even after tools operated in dedicated checkouts. Reviewed ownership pointers are in [audit-policy.json](../../tools/usage/audit-policy.json); incidental read-only references to another checkout do not make it an owned worktree or transfer tokens to it. Main-worktree integration sessions legitimately discuss many feature branches while their own usage remains assigned to integration.

A session can have more than one goal and a goal can continue across branches. The canonical Save/Load research therefore remains associated with the Save/Load checkout while receiving its own workstream and structured-goal attribution. Discovery/runtime and Freedoom/Ultimate sessions use shared directory buckets to preserve that distinction without inventing precise cutover costs.
