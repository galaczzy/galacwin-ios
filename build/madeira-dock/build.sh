#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2026 125hz
# Madeira Converter Exception: see LICENSE-EXCEPTION.md
#
# Build Madeira Dock (madeira-dock) as a stripped x86-64 PE and stage
# it in the app bundle with its notices:
#   app/Madeira/arm64ec-windows/dockhost.exe
#   app/Madeira/arm64ec-windows/dock-notices.txt
# Both are build outputs (gitignored). The app starts dockhost.exe as
# C:\windows\system32\dockhost.exe; without it, Madeira Dock stays hidden.
#
# Usage: build/madeira-dock/build.sh [--check]
#   --check  also build and run Dock's own unit tests with the host compiler
#            (madeira-dock/tools/check.sh; needs cc with ASan/UBSan).
# LLVM_MINGW=<dir with x86_64-w64-mingw32-clang> overrides the toolchain.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$REPO_ROOT/madeira-dock"
PATCH="$DIR/security-hardening.patch"
DOCK_REVISION=8c98616a68c45857c1b0fd1bc58268249b3aa3aa
MINGW="${LLVM_MINGW:-$REPO_ROOT/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin}"
CC="$MINGW/x86_64-w64-mingw32-clang"
OUT="$REPO_ROOT/app/Madeira/arm64ec-windows"

[ -f "$SRC/src/main.c" ] || { echo "madeira-dock is missing: git submodule update --init madeira-dock" >&2; exit 1; }
[ "$(git -C "$SRC" rev-parse HEAD)" = "$DOCK_REVISION" ] || { echo "unexpected madeira-dock revision" >&2; exit 1; }
[ -f "$PATCH" ] || { echo "missing Dock security patch: $PATCH" >&2; exit 1; }
[ -x "$CC" ] || { echo "missing cross compiler: $CC (set LLVM_MINGW)" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/source"
git -C "$SRC" archive "$DOCK_REVISION" | tar -xf - -C "$TMP/source"
(cd "$TMP/source" && git apply --check "$PATCH" && git apply "$PATCH")

if [ "${1:-}" = "--check" ]; then
    (cd "$TMP/source" && bash tools/check.sh)
fi

# Same flags as Dock's own tools/build.sh: warnings are errors, the runtime is
# linked statically (its notices go into dock-notices.txt) and symbols are
# stripped. -Wl,--no-insert-timestamp keeps the output reproducible.
"$CC" -std=c11 -O2 -Wall -Wextra -Werror -Wno-cast-function-type \
    -static -Wl,--strip-all -Wl,--no-insert-timestamp \
    -o "$TMP/dockhost.exe" "$TMP"/source/src/*.c -ladvapi32

section() { printf '\n\n==== %s ====\n\n' "$1"; }
{
    cat "$TMP/source/LICENSE"
    printf '\nCorresponding source: https://github.com/125hz/madeira-dock (commit %s)\n' \
        "$DOCK_REVISION"
    printf 'GalacWin security patch SHA-256: %s\n' "$(shasum -a 256 "$PATCH" | awk '{print $1}')"
    section 'LICENSE-EXCEPTION.md (Madeira Converter Exception)'
    cat "$TMP/source/LICENSE-EXCEPTION.md"
    section 'COPYING (GNU General Public License, version 3)'
    cat "$TMP/source/COPYING"
    section 'MinGW-w64 runtime notice (statically linked runtime)'
    cat "$TMP/source/notices/MinGW-w64-runtime.txt"
    section 'LLVM runtime notice'
    cat "$TMP/source/notices/LLVM.txt"
} > "$TMP/dock-notices.txt"

mkdir -p "$OUT"
cp "$TMP/dockhost.exe" "$TMP/dock-notices.txt" "$OUT/"
if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$OUT/dockhost.exe"; else sha256sum "$OUT/dockhost.exe"; fi
ls -la "$OUT/dockhost.exe" "$OUT/dock-notices.txt"
