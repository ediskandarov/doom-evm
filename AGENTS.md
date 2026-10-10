# DOOM on EVM — Agent Instructions

## Mandatory Gitmoji commits

- Every new commit, including merge commits, MUST begin with an appropriate Gitmoji, followed by a concise imperative description: `<gitmoji> <description>`.
- Examples: `✨ Port original automap logic`, `🐛 Fix sprite bounds`, `✅ Verify native equivalence`, `📝 Record goal handoff`, `🔀 Merge verified status bar`.
- Keep each commit focused on one logical change. Do not use generic messages or rewrite existing history to retrofit Gitmoji.

## Single Writer to Main

- Only the designated integration agent may modify the main worktree, commit to main, merge into main, or push main. Feature agents never write or push main.
- Before integration, refresh origin/main, verify the main worktree is clean and synchronized, and inspect feature changes and shared interfaces.
- Preserve original feature commits, completed documentation and evidence. Integrate on top of latest main; never force-push, reset published main, or rewrite published history.
- The integrator owns shared state/types, EVM adapters, browser/Frame protocols, WAD schemas and common acceptance runners. Coordinate and freeze interface changes before dependent work.

## Independent worktree ownership

- One Goal / One Worktree / One Owner: assign each feature goal a dedicated worktree and owner; integration happens only in the designated main worktree.
- Each feature agent works only in its assigned branch/worktree and owned files. Check branch, HEAD and working-tree status before starting; protect existing changes.
- Do not modify, clean, reset, rebase or remove another agent's worktree or branch. Do not change shared files outside assigned ownership; hand required changes to the integrator.
- Handoff includes the exact commit SHA, changed files, reproducible verification commands/results, evidence paths, interface requirements and remaining dependencies.

## Independent runtime ownership

- Use an isolated runtime and unoccupied ports for each goal; refuse occupied ports. Never attach to, reset, reconfigure or terminate another owner's Anvil/runtime.
- The current playground reserves `127.0.0.1:18880` (Anvil) and `127.0.0.1:8088` (browser). Do not use these ports for verification.
- Track runtimes started by the goal and stop only those instances during cleanup; preserve external environments.

## Goal-specific progress

- Work within the authorized goal. Record scope, baseline, ownership, dependencies, verification gates and stop condition before implementation; do not automatically begin later goals.
- Maintain goal-specific reports/evidence. At verified checkpoints, distinguish implementation, integration and verification/acceptance; record commits, commands, counts, limits, blockers and next action.
- The integrator reconciles handoffs into [the shared Phase 4 ledger](docs/PHASE4-PLAN.md). Feature agents keep their own goal records until integration; preserve earlier checkpoints and pending work.
- Record measured start/end times and available usage attribution without estimating missing measurements. Commit verified work, push when authorized, and leave a recoverable handoff and clean tree or explicitly report remaining changes.

## Risk-based Phase 4 verification

- Follow [the Phase 4 policy, section 5](docs/04-IMPLEMENTATION-PLAN-EXTRA.md): build affected roots and run focused Forge/native/Node tests plus affected dependencies. Documentation-only changes need scope, formatting and link checks, not engine rebuilds.
- At integration boundaries, run targeted EVM transaction/browser checks and high-risk inherited cases relevant to the change. Record source/ABI/resource identity, actual results and evidence hashes; claim only demonstrated coverage.
- Do not run the complete inherited Phase 0–3 suite for every goal or small edit. At final Phase 4 acceptance, freeze HEAD/resources/toolchain and run all inherited Phase 0–3 gates and complete Phase 4 acceptance, including native, EVM and browser Frame proofs.
- Preserve accepted tests, fixtures, certificates and telemetry. Add separate evidence for new checkpoints. Never delete tests, weaken assertions or alter native goldens/original C merely to obtain a pass; failed gates remain failed.
- Retain pinned compiler/viaIR settings, EVM hardfork, shared ABIs and execution budgets unless an explicitly authorized, measured change is required. Use local source-preserving fixes for compiler issues.

## C-to-Solidity source fidelity

- Reference `original/DOOM/linuxdoom-1.10` at `a77dfb96cb91780ca334d0d4cfd86957558007e0`. Follow [PORTING.md](PORTING.md) and [the Phase 0–3 plan](docs/03-IMPLEMENTATION-PLAN.md).
- Port corresponding C modules/functions to same-named Solidity libraries. Preserve names, control flow, numeric semantics, call/RNG order and defined original quirks; do not replace algorithms with high-level substitutes.
- Keep function mappings, native source spans/hashes and declared host/context adaptations. Document unsupported domains, undefined C behavior and deliberate deviations; prove defined behavior against the pinned original-C oracle.
- Gameplay, visibility and indexed pixel generation execute in the EVM. Do not inject precomputed host gameplay, visibility or rendered frames into production; browser presentation consumes authenticated EVM output.
- Use Yul only locally with explicit bounds and memory-safety proofs. Keep original-source and asset provenance/licenses intact.
