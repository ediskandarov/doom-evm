# Ultimate speedrun feature handoff

Verified source/report checkpoint: `69c83d5ae8e92750645c16f5e635c52a2dd88587` on
`feat/ultimate-episode-speedruns`, based on origin/main
`51e879247bb3d6d809af8a0516a097f71c3d0756`.
Durable worktree: `~/sandbox/doom-evm-ultimate-speedruns`.
The final handoff commit adds metadata only.

[Episode report](ULTIMATE-SPEEDRUNS.md) and [handoff manifest](../artifacts/ultimate-speedruns/handoff.json)
contain counts, changed files, commands/results, source/resource identities and
remaining dependencies. Five complete videos are local under
`artifacts/local/ultimate-speedruns/E1M{1,2,4,7,9}/full-rate/speedrun-e1mN.mp4`.
All nine selected maps have complete native/EVM gameplay proof. Four rendering
blockers are reproduced unknown owner-slot bytes; their accepted partial frames,
source tapes, failures and restore points are retained independently.

Recheck in this worktree:

```sh
source scripts/env.sh
python3 tools/reference/ultimate_speedruns/stage-inputs.py
python3 tools/reference/ultimate_speedruns/episode-summary.py
python3 tools/reference/ultimate_speedruns/test_checkpoint_cleanup.py
```

These checks verify eleven original archive/demo identities, all nine per-map
proof manifests and the publication/corruption/relocation cleanup guards.
Per-map raw receipt/world/pixel/media verification and rebuilding commands are
in [the reusable suite instructions](../tools/reference/ultimate_speedruns/README.md).
Commercial resources/worlds/artwork/full receipts/video remain ignored locally;
Git intentionally cannot restore those files. Preserve the local artifact tree.
Native commands recorded before relocation retain their historical temporary
paths; the coordinator resolves current owned paths. Checkpoint file-path
metadata is repaired and original pointer copies are retained; game/chain/frame
bytes and hashes are unchanged.

Only feature-owned support adapters and recording/reference tools are added.
Shared Freedoom/engine types, production ABI, original C, game algorithms,
allocator/provenance guards, compiler/hardfork and goldens remain unchanged.
No other feature branch is merged, no main write/push occurs, and all owned
Anvil/native/monitor jobs are stopped. Main integration and full production
Phase 4/browser acceptance belong to the integrator. The prior speedrun worktree
and its committed/ignored recovery evidence remain available.
