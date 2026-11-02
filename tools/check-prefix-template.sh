#!/bin/sh
# Inspect the prefix archive without extracting or executing it. Any malformed
# path, link, installer or executable prevents it from entering the IPA.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ARCHIVE="${1:-app/Madeira/prefix-template.tar.gz}"
python3 "$SCRIPT_DIR/security/check_prefix_template.py" "$ARCHIVE"
