# Toolchain and runtime profiles

`toolchain.lock.json` pins binary URLs and SHA-256 digests taken from the official release metadata. `scripts/install-toolchain.py` verifies all downloads before replacing project-local executables. It does not update global tools. A failed download can be rerun. Node and Python are external prerequisites.

| Component | Tested baseline |
|---|---|
| Forge / Anvil / Cast | 1.8.5, commit `51a52c59cffd940f76eddd0b4bb1791aa4b5ac7f` |
| Solidity | 0.8.37, commit `f401782d`, native Darwin appleclang binary |
| Node | 24.11.0; built-in fetch/WebSocket, no npm dependencies |
| Python | 3.14.2 observed; scripts use standard library, Python 3.10+ |
| Host | macOS 15.7.9 arm64 |
| Browser | Chrome 155.0.8059.40 in recorded browser experiment |
| Compiler settings | optimizer on, 200 runs, `via_ir = true`, Cancun |
| Native C oracle | Apple clang 17.0.0 (clang-1700.0.13.5), target arm64-apple-darwin24.6.0; O0/O2 and UBSan comparisons. Exact flags and semantics in `tools/reference/reference.py` and fixture metadata. |

Official release sources: [Foundry v1.8.5](https://github.com/foundry-rs/foundry/releases/tag/v1.8.5), [Solidity v0.8.37](https://github.com/argotorg/solidity/releases/tag/v0.8.37). `python3 scripts/check-toolchain.py` verifies local tool versions/commits, upstream SHA, Node, and effective Forge compiler settings. The lock also provides Linux binary digests; Linux execution has not been verified in this run.

Use `source scripts/env.sh` from the repository root to select the project-local tools and shared gas policy, or `.toolchain/bin/forge` directly with its configured default. Bare global `forge` may still refer to the previous installation. `foundry.toml` pins the project-local compiler path; its exact version is guarded by Solidity pragmas and the check script.

## Working Anvil startup

```sh
./scripts/start-anvil.sh
# Optional bounded startup check:
ANVIL_PORT=18545 ./scripts/start-anvil.sh --check --quiet
```

The launcher binds localhost and starts the pinned binary with:

```text
--host 127.0.0.1 --port 8545 --chain-id 31337 --hardfork cancun
--disable-code-size-limit --disable-block-gas-limit --memory-limit 1073741824
```

Then it loads `execution-budget.json` (default **10,000,000,000 gas**), applies `DOOM_GAS_LIMIT` or `FOUNDRY_GAS_LIMIT` overrides, calls `anvil_setBlockGasLimit` with the selected value (default `0x2540be400`), mines one empty initialization block with `evm_mine`, and verifies that header budget. It waits for the owned child, forwards signals, and cleans up on error. It refuses to attach to an already occupied port.

**Measured correction to the design's illustrative command:** Anvil 1.8.5 rejects `--gas-limit` together with `--disable-block-gas-limit`. Furthermore, setting the gas limit by RPC affects the next mined block, not the already-existing genesis header. This is why the launcher uses an RPC and initialization block. The transport benchmark verifies the limit in its deployment block.

## Executable limit checks

`python3 scripts/probe-limits.py` starts separate temporary control and relaxed nodes, uses ordinary EVM initcode/runtime bytecode, records results in `artifacts/local/runtime-limits.json`, and stops each node. The historical one-billion run is retained unchanged in `artifacts/phase0/runtime-limits.json`; current 10-billion launcher/probe evidence is [separate](artifacts/phase3/execution-python-checkpoint.json).

| Probe | Control | Relaxed configuration |
|---|---|---|
| 25,000-byte runtime, 25,014-byte initcode | Deployment receipt fails | Normal deployment succeeds; on-chain code length checked |
| 50,000-byte runtime, 50,014-byte initcode | RPC rejects max initcode size | Normal deployment succeeds; on-chain code length checked |
| Touch memory at 65,536 and return word 42 | 1 KiB control fails `MemoryLimitOOG` | 1 GiB configured limit permits it |
| Self-transfer allowance selected budget + 1 (historically 1,000,000,001) | RPC rejects allowance | RPC returns hash, but no receipt within about 2.5 seconds; subsequent transaction lookup is null |
| Small `eth_call` with allowance selected budget + 1 | Returns word 42 with ordinary memory setting | Returns word 42 |

The gas allowance probe does not consume the selected budget. It shows that disabling admission checks does not guarantee successful mining. The fixture transactions request at most the configured block budget. No claim of unlimited execution is made. A 1 GiB memory setting is not a measurement of host memory capacity, and the probe deliberately allocates only about 64 KiB. Large engine deployments and real BSP recursion must still be measured later.

No `anvil_setCode`, special precompile, EVM fork, or native renderer is used. In this exact pinned Anvil version, disabling the code-size limit also allowed the tested initcode above 49,152 bytes; do not assume other versions behave the same way.

## Commands and evidence

`python3 scripts/verify-phase0.py` runs version checks, schema validation, formatting, a forced build, all Foundry tests with a fixed fuzz seed, protocol unit tests, the compiler-pipeline comparison, startup/limit probes, the transaction benchmark, and the real-browser check. It records exit codes, elapsed times, command logs and source hashes. Browser execution requires installed Chrome/Chromium (`CHROME_BIN` override).

Foundry may print informational AST notices for header-only struct modules and cast lint warnings in the synthetic stack fixture. Compilation succeeds; the spike documents bounded toy arithmetic, not C numeric equivalence. No unsafe assembly is present.

## Phase 1 verification

`python3 scripts/verify-phase1.py` runs the complete foundation gate, including every Phase 0 check. The C baseline flags are `-std=c99 -O2 -fwrapv -fno-strict-aliasing -ffp-contract=off -fno-fast-math`; the O0 comparison changes only optimization, while the sanitizer build removes `-fwrapv` and adds `-fsanitize=undefined,float-cast-overflow -fno-sanitize-recover=all`. Compiler/target drift fails explicitly. See `tools/reference/README.md` for original source extraction and undefined-domain audits. Node 24 native type stripping executes the TypeScript WAD tools without npm dependencies.

Additional cast warnings in numerical tests concern explicit narrowing to the frozen ABI; production narrowing is documented and compared with the C oracle. The placement fixture may trigger an event-after-external-call lint at SHA-256: its only call is the standard SHA-256 precompile, with no arbitrary callback. Memory-safe table loads and EXTCODECOPY writes are bounded and documented beside their assembly.

## Configurable local gameplay execution budget

```sh
source scripts/env.sh
DOOM_GAS_LIMIT=20000000000 ./scripts/start-anvil.sh
DOOM_GAS_LIMIT=20000000000 python3 scripts/verify-phase2.py
# Direct Forge overrides use its native environment variable:
FOUNDRY_GAS_LIMIT=20000000000 .toolchain/bin/forge test
```

The shared JSON default is 10 billion. Node/Python tools normalize child
environments to both variables; the shell setup does the same. A direct Forge
command reads `foundry.toml` or `FOUNDRY_GAS_LIMIT`; source `scripts/env.sh` after
changing the JSON policy to propagate it to direct commands. Explicit browser
configs carry the selected budget, with a current-block fallback for old configs.

The local budget is independent of economic gas efficiency. Original production
resource preparation and level startup run in one transaction, measured at
1,621,868,997 gas. Historical one-billion measurements remain unchanged. Solc
0.8.37, viaIR, optimizer 200 and Cancun, the code-size policy and 1 GiB memory
limit remain unchanged. Stack/code-generation errors, invalid memory access and
unknown physical backing bytes remain separate failure categories.
