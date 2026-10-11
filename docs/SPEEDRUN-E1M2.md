# E1M2 authentic full-rate replay

Native checkpoint: author AZRAEL-II (leaderboard account LANCASTER_),
[`ylpjl2nm`](https://www.speedrun.com/freedoom_phase_1/runs/ylpjl2nm),
[original archive](https://drive.proton.me/urls/HQTD1QTR4C#S5CiNp36Dwh9).
The 8,562-byte `fd1m2-55s490ms.lmp` has SHA-256
`810dd601351b6ec54aca26a2ef04cafefbc556ee07c53ce3d870b5ff9abe0306`.
Original notes name DSDA 0.25.2; the preserved footer identifies DSDA 0.28.2
and complevel 3. Preserve that discrepancy. Recording-time IWAD identity is
unknown. The pinned Freedoom 0.13.0 SHA-256 is verified independently.

Original `G_ReadDemoTiccmd` exactly agrees with every decoded command. The
version-109 tape has 2,091 tics, skill 0, retail E1M2, player 0, monsters enabled,
no fast/respawn/deathmatch. Stock Linux DOOM's version-110 loader rejects the
header; the preserved original command reader and gameplay harness accept the
four-byte format without changing original C. The DSDA demo/features checksum
passes; it is not an IWAD hash.

Native O2, O0, ASan/UBSan and ASan/UBSan with fresh allocation fill `0xa5` all
reach genuine normal exit at line 737, tic 1,942 (55.485714 seconds). All 1,943
DSG1 observations and diagnostics agree across all four profiles. Remaining
149 tape commands follow the exit and are preserved. Timings and exact
commands are in [native-result.json](../artifacts/episode-speedruns/E1M2/native-result.json);
[the manifest](../artifacts/episode-speedruns/E1M2/native-evidence-manifest.json)
binds the original tape, compressed state stream and native build manifests.

EVM recording, pixel comparisons, provenance and media verification are pending.
No EVM exit or universal pixel equality is claimed at this native checkpoint.
