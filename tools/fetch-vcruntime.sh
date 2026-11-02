#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/tools/build/prepare-vcruntime.sh"
python3 "$ROOT/tests/host/check-vcruntime.py" --strict
