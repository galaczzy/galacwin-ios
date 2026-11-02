#!/usr/bin/env python3
"""List tracked binary inputs without executing or trusting them."""

import csv
import hashlib
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
EXTENSIONS = (
    ".dll", ".exe", ".a", ".dylib", ".so", ".zip", ".cab",
    ".msi", ".ipa", ".metallib", ".tar.gz", ".tar.xz",
)
MAGIC = {
    b"MZ": "PE",
    b"\x7fELF": "ELF",
    b"!<arch>\n": "archive",
    b"PK\x03\x04": "ZIP",
    b"\x1f\x8b": "gzip",
    b"\xcf\xfa\xed\xfe": "Mach-O",
    b"\xfe\xed\xfa\xcf": "Mach-O",
    b"\xca\xfe\xba\xbe": "Mach-O fat",
}


def classify(header: bytes) -> str:
    return next((label for signature, label in MAGIC.items() if header.startswith(signature)), "other")


def digest(path: pathlib.Path) -> tuple[str, int, str]:
    sha = hashlib.sha256()
    size = 0
    header = b""
    with path.open("rb") as source:
        while block := source.read(1024 * 1024):
            if not header:
                header = block[:8]
            sha.update(block)
            size += len(block)
    return sha.hexdigest(), size, classify(header)


def main() -> None:
    tracked = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "-z"],
        check=True, capture_output=True,
    ).stdout.decode("utf-8", errors="surrogateescape").split("\0")
    writer = csv.writer(sys.stdout, lineterminator="\n")
    writer.writerow(("path", "bytes", "sha256", "kind", "status"))
    for relative in sorted(filter(None, tracked)):
        path = ROOT / relative
        selected = relative.lower().endswith(EXTENSIONS) or relative.startswith("app/Frameworks/")
        if not selected and path.is_file():
            with path.open("rb") as source:
                selected = classify(source.read(8)) != "other"
        if not selected:
            continue
        if not path.is_file():
            writer.writerow((relative, "", "", "", "missing"))
            continue
        sha, size, kind = digest(path)
        writer.writerow((relative, size, sha, kind, "present"))


if __name__ == "__main__":
    main()
