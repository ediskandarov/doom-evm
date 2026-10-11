# Focused Full Video / Options integration checks

Verification-only tools. Read AGENTS.md and
[the integration report](../../../docs/FULL-VIDEO-OPTIONS-INTEGRATION.md).
Never run these in another owner's worktree or over retained evidence. Fixed local
output directories deliberately reject reuse; reproduce in a fresh owned checkout
with authenticated ignored inputs. No MP4 encoding or full historical suite.

Required ignored inputs: pinned Freedoom IWAD, locally supplied Ultimate/DOOM II
IWADs at `artifacts/local/options/{DOOM.WAD,DOOM2.WAD}`, preserved Ultimate bundle
under `artifacts/local/ultimate-speedruns/wad/`, and exact E1M1/E1M2 tape/source/
canonical native delta-state records under their original Ultimate paths. All
resource identities are verified. Do not commit commercial inputs or pixel files.

```sh
.toolchain/bin/forge build src/evm/Doom.sol src/evm/Doom2.sol src/evm/ResourceStore.sol src/support/FullSpeedrunProbe.sol --offline --no-lint
node tools/browser-deployment/package.mjs
node tools/reference/doom2/package.mjs .
python3 tools/reference/options/focused.py
python3 tools/reference/options/startup-native.py
python3 tools/reference/options/status-resize.py
node --test web/menu-input.test.mjs web/input-runtime.test.mjs web/input-loop.test.mjs web/input-app.test.mjs web/install.test.mjs web/input.test.mjs web/doom2-profile.test.mjs web/browser-profiles.test.mjs
node tools/reference/full_options/browser.mjs --port 19371 --http-port 19372 --ultimate-wad artifacts/local/options/DOOM.WAD --doom2-wad artifacts/local/options/DOOM2.WAD
python3 tools/reference/full_options/prepare.py
.toolchain/bin/forge build artifacts/local/full-options-main/observer/src/support/FullSpeedrunProbe.sol src/evm/ResourceStore.sol --out artifacts/local/full-options-main/observer/out --cache-path artifacts/local/full-options-main/observer/cache --offline --no-lint
python3 tools/reference/full_options/native.py
node tools/reference/full_options/evm.mjs
python3 tools/reference/full_options/e1m2.py
node tools/reference/full_options/e1m2.mjs
```

The exact additional14+4 Forge commands are recorded in this goal's command JSONs.
Browser checks are a bounded derivative of the unchanged Options acceptance
runner: skills2/4 plus representative map9 or MAP32, with original New Game,
Messages/view/API/rollback and three-game reuse checks retained.

`prepare.py` copies current source into an ignored diagnostic consumer. It composes
existing DoomMenu/DoomUI with the recorder's callbacks; it does not modify the
production recorder or ship this test API to the browser. The E1M8 entry is an
explicit finale fixture, never a claimed genuine exit. `native.py` retains original
C bodies and executes original view-size application at display, borrowed assets
including STTMINUS and matching sampled ST/HU history. `evm.mjs` deploys ordinary
resource/consumer contracts and replays authentic gameplay; native pixels are only
compared after receipts. UI clocks and menu packets do not advance gameplay.

Runners refuse occupied dedicated ports and stop only their own runtimes. The
browser site is an isolated copy excluding local diagnostic config overrides.
Frames/receipts/commercial native resources remain ignored; publish hashes and
metadata only. Failed helper/reference attempts remain separate and do not alter
existing golden files or accepted source evidence.
