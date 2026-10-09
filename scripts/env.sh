#!/usr/bin/env bash
# Source from the repository root: source scripts/env.sh
DOOM_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$DOOM_PROJECT_ROOT/.toolchain/bin:$PATH"
