# DOOM on EVM 👹

But can it run DOOM? That's the mission. Phase 0 proves the workbench: a Solidity-generated 64 KB test frame travels through an Anvil transaction, a `Frame` event and a browser Canvas. **The DOOM engine is not implemented yet.**

The destination is a readable port of original `linuxdoom-1.10` to Solidity/Yul, with C-to-Solidity file/function traceability. The browser sends input and displays pixels; the EVM will do the rendering and simulation.

## Press start

Prerequisites: Git, Python 3.10+, Node **24.11.0**, and Chrome/Chromium for the browser check. Native installation is checksum-pinned for macOS arm64 and Linux amd64/arm64; this Phase 0 run was verified on macOS arm64.

```sh
git submodule update --init --recursive
python3 scripts/install-toolchain.py
export PATH="$PWD/.toolchain/bin:$PATH"
python3 scripts/check-toolchain.py
forge build
forge test
python3 scripts/verify-phase0.py
```

Tools install under ignored `.toolchain/`; global Foundry is left alone. No npm dependencies are required. Set `CHROME_BIN` if Chrome is not at its standard macOS path. The verification command starts and stops temporary localhost nodes and a headless browser, and writes fresh results to `artifacts/local/`.

## Emit something suspiciously pixel-shaped

```sh
# Terminal 1
./scripts/start-anvil.sh
# Terminal 2
node tools/transport/benchmark.mjs --rpc http://127.0.0.1:8545 --ws ws://127.0.0.1:8545
node tools/transport/serve.mjs
```

Open <http://127.0.0.1:8080>. The moving grayscale pattern is synthetic and generated inside Solidity. It is our transport test, not a Doom screenshot.

## Mission briefing

- [Phase 0 report and acceptance evidence](docs/PHASE0-REPORT.md)
- [Toolchain and measured Anvil limits](TOOLCHAIN.md)
- [C → Solidity map and progress](PORTING.md)
- [Frozen interfaces](docs/PHASE0-INTERFACES.md), [schemas](docs/SCHEMAS.md)
- [Architecture decisions](docs/01-IDEA-AND-DECISIONS.md), [technical specification](docs/02-TECHNICAL-SPECIFICATION.md), [implementation plan](docs/03-IMPLEMENTATION-PLAN.md)
- [Transport experiment](docs/EVENT-TRANSPORT.md), [stack experiment](docs/STACK-PRESSURE.md)
- [Pinned upstream and attribution](UPSTREAM.md), [GPL-2.0 license](LICENSE)

Phase 1 is intentionally not started. No proprietary WAD assets are included. Future public asset fixtures use Freedoom Phase 1 with their own license and checksums.
