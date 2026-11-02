#!/usr/bin/env python3
"""Inspect the bundled Wine prefix archive without extracting or running it."""

from pathlib import Path, PurePosixPath
import hashlib
import sys
import tarfile

EXPECTED_SHA256 = "66ebda0615ea780cd3f8c4c0744553a539e86bd4c97fc338355e62f7d8fdba56"
MAX_ARCHIVE_SIZE = 8 * 1024 * 1024
BLOCKED_EXTENSIONS = {
    ".exe", ".dll", ".drv", ".sys", ".com", ".msi", ".msp", ".scr",
    ".ocx", ".cpl", ".bat", ".cmd", ".ps1", ".vbs", ".vbe", ".js",
    ".jse", ".hta",
}
MAX_MEMBERS = 512
MAX_FILE_SIZE = 16 * 1024 * 1024
MAX_TOTAL_SIZE = 64 * 1024 * 1024


def check(archive: Path, expected_hash: str | None = EXPECTED_SHA256) -> tuple[int, int]:
    if archive.stat().st_size > MAX_ARCHIVE_SIZE:
        raise ValueError("compressed archive size exceeds limit")
    if expected_hash is not None:
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if digest != expected_hash:
            raise ValueError(f"unapproved archive SHA-256: {digest}")
    seen = set()
    total_size = 0
    with tarfile.open(archive, "r:gz") as package:
        count = 0
        for member in package:
            count += 1
            if count > MAX_MEMBERS:
                raise ValueError("too many archive entries")
            name = member.name
            path = PurePosixPath(name)
            if (not name or name.startswith("/") or "\\" in name or
                    ".." in path.parts or path.parts[0] != "prefix" or
                    str(path) != name.rstrip("/") or name in seen):
                raise ValueError(f"unsafe or duplicate archive path: {name}")
            seen.add(name)
            if member.isdir():
                continue
            if not member.isfile():
                raise ValueError(f"link or special file in archive: {name}")
            if member.mode & 0o111 or path.suffix.lower() in BLOCKED_EXTENSIONS:
                raise ValueError(f"executable or installer in archive: {name}")
            if member.size < 0 or member.size > MAX_FILE_SIZE:
                raise ValueError(f"archive entry size exceeds limit: {name}")
            total_size += member.size
            if total_size > MAX_TOTAL_SIZE:
                raise ValueError("archive total size exceeds limit")
    if count == 0:
        raise ValueError("archive is empty")
    return count, total_size


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_prefix_template.py ARCHIVE")
    try:
        count, size = check(Path(sys.argv[1]))
    except (OSError, ValueError, tarfile.TarError) as error:
        raise SystemExit(f"prefix template rejected: {error}")
    print(f"prefix template accepted: {count} entries, {size} uncompressed bytes")
