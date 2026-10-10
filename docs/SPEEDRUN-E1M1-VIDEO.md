# EVM E1M1 speedrun video recording

## Scope checkpoint

Independent extension of the verified real demo replay at `bb16afd879d5fe818ada5a21834027c07a4b3803`; existing worktree `/Users/eduard/sandbox/doom-evm-speedrun`, branch `feat/phase4-speedrun-e1m1`. Start measured 2026-10-10 15:38:14 UTC.

Ownership: new speedrun video support contract, recording/media runners and this report only. Preserve the accepted no-render contract/runner, original tape, native snapshots, existing verification and prior report. No production contract, original C, main, shared Phase4 ledger, other worktree or runtime change.

Dependencies: pinned native replay evidence and IWAD, authenticated resource deployment, existing `DoomGame.render` and frozen `IFrameProtocol.Frame` event, ffmpeg/ffprobe and host-only palette/PNG/nearest-neighbor conversion. Runtime prefers checked-free port18620; reject occupied/reserved ports and stop only the owned Anvil.

Verification gates: focused affected-root build; verbatim original demo commands and all280 native gameplay snapshots; genuine exit; actual EVM-rendered Frame receipts and pixel hashes; capture has no persisted gameplay effect, while reporting renderer effects on its temporary memory copy; authenticated palette; precise35Hz media timing,1280x800 raster and4:3 presentation; visual inspection of representative frames; old offline replay proof still passes.

Stop after generating ignored MP4/contact sheet/frame manifest, verifying and committing reusable tools/docs plus small checkpoint evidence. No rendering in native C or JavaScript, no episode progression, no production API changes, no full inherited acceptance.

Initial design: an isolated video companion to the existing runner and support probe, retaining their accepted source identity. Render only a memory copy of authoritative saved state and emit standard Frame events. Preserve the existing gameplay tape and serialize every post-tic DSG1 observation. Sampling starts at one frame for each five-tic gameplay transaction, with the final four-tic interval retained. Each sampled post-tic image represents its preceding interval, held for exactly that interval's length divided by35 seconds; finer sampling approaches ordinary35fps post-tic display. Host media conversion only expands authenticated palette indexes, repeats/scales pixels and encodes.

Implementation and new execution evidence pending at this scope checkpoint.
