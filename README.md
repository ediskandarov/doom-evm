# DOOM on EVM 👹

But can it run DOOM? The static renderer produces eight Freedoom E1M1 views inside the EVM, matching all 64,000 pixels from the original C renderer. BSP, textured walls, floors, ceilings, sky and sprites are implemented. **Phase 2 is verified: ordinary deployment, transaction events, browser pixels, 196 tests and every Phase 0/1 gate pass. Gameplay comes next.**

The destination is a readable port of original `linuxdoom-1.10` to Solidity/Yul, with C-to-Solidity file/function traceability. The browser displays transaction pixels; the EVM computes the scene. Movement, weapons and game simulation belong to Phase 3.

## Press start

Prerequisites: Git, Python 3.10+, Node **24.11.0**, and Chrome/Chromium for the browser check. Foundry installation is checksum-pinned for macOS arm64 and Linux amd64/arm64. The native reference gate currently requires Apple clang **17.0.0 (clang-1700.0.13.5)** on **arm64-apple-darwin24.6.0**; other native profiles need review. This run was verified on macOS arm64.

```sh
git submodule update --init --recursive
python3 scripts/install-toolchain.py
export PATH="$PWD/.toolchain/bin:$PATH"
python3 scripts/check-toolchain.py
python3 scripts/verify-phase2.py
```

Tools install under ignored `.toolchain/`; global Foundry is left alone. No npm dependencies are required. Set `CHROME_BIN` if Chrome is not at its standard macOS path. The full verifier downloads and checks the pinned Freedoom archive, builds the original C oracle, preserves every Phase 0 gate, starts and stops temporary localhost nodes and a headless browser, and writes fresh results to `artifacts/local/`. The original `python3 scripts/verify-phase0.py` command remains available.

## Run the real static view

After the verifier prepares the pinned resources:

```sh
# Terminal 1: deploy, verify, and keep the local node running
node tools/renderer/verify.mjs --keep-alive
# Terminal 2
node tools/transport/serve.mjs
```

Open <http://127.0.0.1:8080> and click **Run DOOM**. Each click renders the static
E1M1 view in a new transaction. Ctrl-C in the first terminal stops its Anvil.
See [the deployment/browser report](docs/PHASE2-E2E.md) for pixels, receipts,
gas, memory, timings and the precise static scope.

![Freedoom E1M1 rendered inside the EVM](tools/renderer/evidence/renderer.frames/full-angle0/frame.png)

## Transport test pattern

```sh
# Terminal 1
./scripts/start-anvil.sh
# Terminal 2
node tools/transport/benchmark.mjs --rpc http://127.0.0.1:8545 --ws ws://127.0.0.1:8545
node tools/transport/serve.mjs
```

Open <http://127.0.0.1:8080>. The moving grayscale pattern is synthetic and generated inside Solidity. It is our transport test, not a Doom screenshot.

For the same mock frame using actual Freedoom colors after running the verifier:

```sh
node tools/transport/benchmark.mjs --rpc http://127.0.0.1:8545 --palette artifacts/local/wad/palette.json
```

Reload the browser. The image is still a transport test, now colored by PLAYPAL.

## Mission briefing

- [Phase 2 acceptance ledger](docs/PHASE2-REPORT.md) and [frozen renderer interfaces](docs/PHASE2-INTERFACES.md)
- [Phase 1 report and acceptance evidence](docs/PHASE1-REPORT.md)
- [Phase 0 report and acceptance evidence](docs/PHASE0-REPORT.md)
- [Toolchain and measured Anvil limits](TOOLCHAIN.md)
- [C → Solidity map and progress](PORTING.md)
- [Phase 1 interfaces](docs/PHASE1-INTERFACES.md), [Phase 0 interfaces](docs/PHASE0-INTERFACES.md), [schemas](docs/SCHEMAS.md)
- [Architecture decisions](docs/01-IDEA-AND-DECISIONS.md), [technical specification](docs/02-TECHNICAL-SPECIFICATION.md), [implementation plan](docs/03-IMPLEMENTATION-PLAN.md)
- [Transport experiment](docs/EVENT-TRANSPORT.md), [stack experiment](docs/STACK-PRESSURE.md)
- [Pinned upstream and attribution](UPSTREAM.md), [GPL-2.0 license](LICENSE)

No proprietary WAD assets are included. Freedoom fixtures carry their own license and checksums; the full WAD stays in ignored local artifacts.
