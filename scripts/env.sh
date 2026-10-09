#!/usr/bin/env bash
# Source from the repository root: source scripts/env.sh
if [[ -n ${ZSH_VERSION-} ]]; then
    DOOM_ENV_FILE="${(%):-%x}"
else
    DOOM_ENV_FILE="${BASH_SOURCE[0]}"
fi
DOOM_PROJECT_ROOT="$(cd "$(dirname "$DOOM_ENV_FILE")/.." && pwd)"
unset DOOM_ENV_FILE
export PATH="$DOOM_PROJECT_ROOT/.toolchain/bin:$PATH"
DOOM_EXECUTION_GAS="$(python3 "$DOOM_PROJECT_ROOT/scripts/execution_budget.py")"
export DOOM_GAS_LIMIT="$DOOM_EXECUTION_GAS"
export FOUNDRY_GAS_LIMIT="$DOOM_EXECUTION_GAS"
unset DOOM_EXECUTION_GAS
