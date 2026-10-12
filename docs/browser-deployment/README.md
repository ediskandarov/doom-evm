# Play from the browser

Start with the [macOS getting-started guide](../GETTING-STARTED.md) for prerequisites
and the tested SteamCMD IWAD procedure. The [current compatibility matrix](../COMPATIBILITY.md)
separates available features from finite acceptance coverage. All 32 DOOM II maps
have startup coverage; full gameplay replay acceptance covers MAP01 and MAP07.

This checkout includes authenticated, precompiled production contracts. Players do not compile Solidity, run deployment scripts, configure contract addresses or provide private keys. The browser deploys ordinary CREATE transactions from an unlocked local Anvil development account. Existing Frame/input/resource selectors remain compatible; policy initialization and inspection APIs are additive.

The launcher plays **Freedoom 0.13.0, Ultimate DOOM 1.9 (Episode One), and DOOM II 1.9 (MAP01–MAP32)** through the same production menu/UI runtime. Ultimate requires a locally supplied exact `DOOM.WAD` with MD5 `c4fe9fd920207691a9f493668e0a2083`; commercial files and extracted artwork are never shipped with the website or uploaded to a website server. The file is authenticated and packed in browser memory, then resource transactions go only to the selected localhost Anvil. IndexedDB temporarily retains the exact pending transaction calldata for safe recovery; completed journals retain hashes/addresses/receipts, not the IWAD file.

Interactive installation explicitly calls `initializeMenuWithPolicy(false,3)` for Freedoom/Ultimate and `initializeMenuWithMemoryProfile(false,3)` for DOOM II. Mode 3 is the existing experimental deterministic virtual-pointer/owner-slot profile; Solidity defaults remain unchanged. Strict and the other existing modes remain available through the policy API for diagnostics. Unknown memory reads still revert, and no Relaxed Rendering is implemented. See [the profile and compatibility contract](../ULTIMATE-BROWSER.md#explicit-interactive-memory-policy).

DOOM II requires the classic local `DOOM2.WAD`, MD5 `25e1459ca71d321525f84628f45ca8cd`. Its separate authenticated production adapter reuses the same deployment manager, gameplay, renderer, UI and Frame/input protocol. MAP30 text is supported; the unported cast sequence explicitly rejects at its existing boundary. See [the source coverage and limitations](../doom2/REPORT.md).

## Prepare the website once (maintainer)

The open-source Freedoom IWAD is an ignored website payload, staged from the existing authenticated pipeline:

```sh
source scripts/env.sh
node tools/wad/download.ts artifacts/local/freedoom
```

The committed `web/install-assets` and `web/doom2-assets` contract artifacts need
no player build. Maintainers should use the [production build and combined
packaging commands](../DEVELOPMENT.md#build-the-browser-contracts), which validate
compiler metadata and source hashes. For the committed release, stage the
authenticated Freedoom file; its license is already included:

```sh
cp artifacts/local/freedoom/freedoom1.wad web/install-assets/freedoom1.wad
```

The browser independently verifies the WAD, canonical packed bundle, directory, ordered chunk runtime hashes, palette and contract artifacts. Serve the `web` directory from localhost at a stable origin; changing the origin changes browser storage, but on-chain discovery can recover a missing journal.

```sh
python3 -m http.server 18992 --bind 127.0.0.1 --directory web
```

## Install and play (player)

Start a dedicated Anvil in another terminal. Refuse occupied ports. These limits are required by the existing production engine, whose runtime exceeds standard Ethereum contract limits:

```sh
.toolchain/bin/anvil --host 127.0.0.1 --port 18991 --chain-id 31337 \
  --hardfork cancun --disable-code-size-limit --no-request-size-limit \
  --memory-limit 1073741824 --gas-limit 10000000000 \
  --allow-origin http://127.0.0.1:18992
```

Do not use the reserved playground ports 18880/8088. Use the exact website origin in `--allow-origin`; keep the node bound to loopback and unforked. The browser does not invoke unsafe Anvil configuration/reset/impersonation controls, connect public RPCs, use wallet providers or request keys. Connection is explicit and permitted only from a localhost website to an HTTP localhost Anvil with chain ID 31337 and Cancun. A normal public Ethereum node is incompatible with these execution limits.

1. Open `http://127.0.0.1:18992` in Chrome or another browser supporting IndexedDB and Web Locks.
2. Set Local Anvil RPC to `http://127.0.0.1:18991`, then **Connect**.
3. Select Freedoom, Ultimate DOOM with your local exact `DOOM.WAD`, or DOOM II with your local exact `DOOM2.WAD`. After IWAD verification, click **Install / resume**. Progress reports authenticated resource uploads, contract deployment, initialization and verification.
4. Click **Play**. Canvas displays the original EVM-generated menu. Use arrows and Enter to choose New Game and skill (Episode One also shows its episode selection). Gameplay and the menu remain inside the EVM. WASD/arrows move, Shift runs, Ctrl fires, Space/E uses doors, Tab opens automap, Escape opens the original menu.

The first installation uploads up to 1,755 Freedoom, 756 Ultimate or 889 DOOM II immutable resource chunks and one production contract. Identical chunk contents share an address. New Game uses the same installed resources and contract. Installation costs and runtime are measured in the acceptance report; no speed or gas estimate is presented as a guarantee.

## Resume and retry

Pause stops at a safe boundary or preserves an in-flight transaction. Close/reload the browser, select the same profile, reconnect and use **Install / resume**. For an incomplete commercial upload, reselect the local IWAD; completed deployments can Play after verification without the file. IndexedDB commits each reserved nonce and exact operation before submission. Reconnect checks canonical receipts, sender/nonce transactions, code and resource identity before trusting the journal. Lost responses are reconciled before replay. An unused reserved nonce can be retried with the exact same nonce/data; a consumed conflicting nonce, unavailable canonical receipt or unknown pending transaction blocks automatic replay with an explicit error.

**Change game** closes the current input loop and subscriptions by returning to the launcher. The last game selection is remembered within the browser tab; reconnection is explicit. Changing the selected profile discovers its own game journal and reusable resource contracts. Switching between completed installations deploys nothing. Journals bind endpoint, genesis, driver, release, IWAD profile and explicit memory policy.

Reloading a verified installation requires read-only discovery and resource/runtime verification; it does not deploy again. A missing local journal triggers a bounded scan of ordinary CREATEs by the development driver, followed by full verification. Dedicated local chains up to 10,000 blocks are supported for discovery/recovery scans. Preserve IndexedDB for longer chains. Use the same website origin and RPC URL for fast journal recovery.

A fresh Anvil restart or reset changes actual chain state even if chain ID stays 31337. The installer checks genesis identity and the first mined operation's canonical block hash; stale journals are archived separately if the anchor disappears or changes. Runtime/resource verification independently rejects changed bytes. After a reset, reconnect and install again. Anvil started from a preserved state can reuse its actual unchanged installation.

If RPC disconnects during submission, restore the same node and retry. Do not manually replay deployment transactions. If Anvil reports a revert, keep the journal and correct its execution limits before retrying. Pending external transactions must be resolved on the user's owned node before installation continues. Only one tab may install on an endpoint at a time.

## Verify deployment

Download and stage Freedoom above before the focused tests. See
[Development and verification](../DEVELOPMENT.md) for native resource prerequisites,
production builds and broader checks. The original single-profile
`check.mjs` is historical: its unavailable-DOOM-II assertions do not describe
the current launcher. Use the three-game runner below for the current release.

Focused tests:

```sh
node --test web/browser-profiles.test.mjs web/doom2-profile.test.mjs \
  web/install.test.mjs web/menu-input.test.mjs \
  web/input-app.test.mjs web/input-loop.test.mjs \
  web/episode.test.mjs web/input-runtime.test.mjs
```

Real Anvil + headless Chrome acceptance (owns and stops its own isolated processes; default ports 19171/19172 must be free):

```sh
node tools/browser-deployment/three-game-check.mjs \
  --port 19171 --http-port 19172 \
  --output-prefix artifacts/local/three-game-browser/reproduction \
  --ultimate-wad /path/to/your/DOOM.WAD \
  --doom2-wad /path/to/your/DOOM2.WAD
```

`CHROME_BIN` can select a different Chrome binary. The cross-game runner performs installations through the actual webpage and commercial File API, checks real receipts and every Canvas pixel against EVM Frame/FramePalette logs, and exercises DOOM II interruption/lost-response recovery, all three gameplay starts/movement, switching, reload without deployment, and same-chainId reset. It observes unchanged deployed default policy 2 before each real explicit policy-3 initializer. Screenshots, journals and commercial Frame bytes stay under `artifacts/local`. The earlier single-profile runners and certificates remain historical source evidence; their harness wiring describes their own checkpoints. [Combined integration coverage](THREE-GAME-INTEGRATION.md) distinguishes fresh verification from inherited acceptance.

The initial browser-only baseline artifacts were reused read-only from the integrated main's `out` directory and independently checked against all source metadata. The initial browser-only goal changed no engine implementation. The subsequent Ultimate production adapter is rebuilt under the same pinned policy, with focused resource, UI/lifecycle and native/EVM comparison gates recorded in the Ultimate handoff.

Ultimate-focused reproduction (commercial outputs remain ignored):

```sh
mkdir -p artifacts/local/ultimate-doom
cp ~/Downloads/doom-steam/base/DOOM.WAD artifacts/local/ultimate-doom/DOOM.WAD
node tools/reference/ultimate_speedruns/pack.ts
node tools/wad/pack.ts artifacts/local/freedoom/freedoom1.wad artifacts/local/wad
python3 tools/ultimate-browser/prepare.py
python3 tools/ultimate-browser/native.py
python3 tools/ultimate-browser/forge.py
```

The real runner serves an isolated website copy with diagnostic configs excluded. Ultimate acceptance compares the original skill screen and first gameplay/Status Bar frame to the focused original-C oracle; it selects all five skills and all nine maps through DOM keyboard input. A bounded original god/noclip keyboard route activates the actual E1M1 exit switch and original intermission, followed by Freedoom installation/gameplay and zero-deployment profile switching. This does not replay all nine speedruns or establish universal native heap/pixel equivalence. Screenshots and commercial frame bytes remain under `artifacts/local`.
