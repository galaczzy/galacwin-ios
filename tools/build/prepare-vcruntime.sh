#!/usr/bin/env bash
set -euo pipefail
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DEST="$ROOT/app/Madeira/x86_64-vcruntime"
CACHE="$ROOT/toolchains/downloads"
EXE="${VC_REDIST_X64:-$CACHE/vc_redist.x64.exe}"
URL="https://aka.ms/vc14/vc_redist.x64.exe"
# The aka.ms URL changes over time. Only this reviewed, signed installer and
# the individually reviewed DLLs below may enter the IPA.
EXPECTED_SHA256=843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c
if [[ -n "${VC_REDIST_X64_SHA256:-}" &&
      "$(printf '%s' "$VC_REDIST_X64_SHA256" | tr 'A-F' 'a-f')" != "$EXPECTED_SHA256" ]]; then
  echo "ERROR: VC_REDIST_X64_SHA256 differs from the approved installer" >&2
  exit 1
fi
DLLS=(
  concrt140.dll
  msvcp140.dll
  msvcp140_1.dll
  msvcp140_2.dll
  msvcp140_atomic_wait.dll
  msvcp140_codecvt_ids.dll
  vcamp140.dll
  vccorlib140.dll
  vcomp140.dll
  vcruntime140.dll
  vcruntime140_1.dll
  vcruntime140_threads.dll
  mfc140.dll
  mfc140u.dll
)

command -v 7zz >/dev/null || { echo "ERROR: 7zz is required (brew install sevenzip)" >&2; exit 1; }
mkdir -p "$DEST" "$CACHE"

if [[ ! -f "$EXE" ]]; then
  echo "Downloading the official Microsoft Visual C++ x64 Redistributable..."
  curl -fL "$URL" -o "$EXE"
fi
ACTUAL_SHA256="$(shasum -a 256 "$EXE" | awk '{print $1}')"
[[ "$ACTUAL_SHA256" == "$(printf '%s' "$EXPECTED_SHA256" | tr 'A-F' 'a-f')" ]] || {
  echo "ERROR: VC redistributable SHA-256 mismatch; refusing to extract" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
7zz x -y "$EXE" -o"$TMP/redist" >/dev/null

# 7-Zip 26 extracts only the Burn UX container, not the attached one that holds
# the CABs, so also carve every embedded CAB out of the EXE by its MSCF header.
python3 - "$EXE" "$TMP/redist" <<'PYCAB'
import struct, sys
from pathlib import Path
data = Path(sys.argv[1]).read_bytes()
i = 0
while (i := data.find(b"MSCF\0\0\0\0", i)) >= 0:
    size = struct.unpack_from("<I", data, i + 8)[0]
    Path(sys.argv[2], f"carved-{i:x}.cab").write_bytes(data[i:i + size])
    i += 8
PYCAB
# The attached container is itself a CAB whose members (a0, a1, ...) are the
# MSIs and payload CABs, with no file extensions.
for cab in "$TMP"/redist/carved-*.cab; do
  [[ -e "$cab" ]] && 7zz x -y "$cab" -o"$TMP/redist/${cab##*/}.d" >/dev/null || true
done

# The current Microsoft x64 package can also contain ARM64 payloads. Extract all
# CABs, then select only PE32+ AMD64 (Machine 0x8664) DLLs by reading each PE
# header. This keeps the build correct even if Microsoft changes CAB ordering.
CABS=()
while IFS= read -r cab; do CABS+=("$cab"); done < <(find "$TMP/redist" -type f -exec sh -c '[ "$(head -c 4 "$1")" = MSCF ]' _ {} \; -print | sort)
(( ${#CABS[@]} > 0 )) || { echo "ERROR: could not locate CAB payloads inside $EXE" >&2; exit 1; }

mkdir -p "$TMP/cabs"
for i in "${!CABS[@]}"; do
  mkdir -p "$TMP/cabs/$i"
  7zz x -y "${CABS[$i]}" -o"$TMP/cabs/$i" >/dev/null || true
done

is_amd64_pe() {
  python3 - "$1" <<'PYPE'
from pathlib import Path
import struct
import sys

p = Path(sys.argv[1])
try:
    data = p.read_bytes()
    if data[:2] != b"MZ" or len(data) < 0x40:
        raise ValueError
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError
    machine = struct.unpack_from("<H", data, pe + 4)[0]
except (OSError, ValueError, struct.error):
    sys.exit(2)

sys.exit(0 if machine == 0x8664 else 1)
PYPE
}

for dll in "${DLLS[@]}"; do
  src=""
  expected="$(awk -v name="$dll" '$2 == name { print $1 }' "$ROOT/tools/build/vc-redist-x64.sha256")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { echo "ERROR: missing approved digest for $dll" >&2; exit 1; }
  while IFS= read -r candidate; do
    if is_amd64_pe "$candidate" &&
       [[ "$(shasum -a 256 "$candidate" | awk '{ print $1 }')" == "$expected" ]]; then
      src="$candidate"
      break
    fi
  done < <(find "$TMP/cabs" -type f \( -iname "$dll" -o -iname "${dll}_*" \) | sort)
  [[ -n "$src" ]] || { echo "ERROR: approved x86_64 $dll not found in Microsoft redistributable" >&2; exit 1; }
  cp "$src" "$DEST/$dll"
done

# Match every extracted DLL to the reviewed Microsoft-signed payload, not only
# the outer redistributable digest. A changed package needs a new review.
(cd "$DEST" && shasum -a 256 -c "$ROOT/tools/build/vc-redist-x64.sha256") || {
  echo "ERROR: extracted Visual C++ DLL does not match its approved digest" >&2
  exit 1
}

shopt -s dotglob nullglob
for file in "$DEST"/*; do
  [[ -f "$file" && ! -L "$file" ]] || {
    echo "ERROR: unexpected non-file in VC runtime bundle: ${file##*/}" >&2
    exit 1
  }
  found=0
  for dll in "${DLLS[@]}"; do [[ "${file##*/}" == "$dll" ]] && found=1 && break; done
  (( found )) || { echo "ERROR: unexpected file in VC runtime bundle: ${file##*/}" >&2; exit 1; }
done

echo "Visual C++ runtime: extracted to $DEST"
