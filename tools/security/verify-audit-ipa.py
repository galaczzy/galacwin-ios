#!/usr/bin/env python3
"""Inspect a downloaded audit IPA without extracting or executing its contents."""

import argparse
import hashlib
import json
import plistlib
from pathlib import Path, PurePosixPath
import stat
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[2]
APP = "Payload/Madeira.app/"


def sha256_stream(stream):
    digest = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(block)
    return digest.hexdigest()


def fail(message):
    raise SystemExit("ERROR: " + message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--sha256", help="Expected IPA SHA-256 from the build log")
    args = parser.parse_args()
    if args.sha256:
        with args.ipa.open("rb") as stream:
            actual = sha256_stream(stream)
        if actual != args.sha256.lower():
            fail(f"IPA SHA-256 differs from the build log: {actual}")
        print("PASS: IPA SHA-256 matches the build log:", actual)

    with zipfile.ZipFile(args.ipa) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        if len(names) != len(set(names)):
            fail("duplicate ZIP entries")
        if len(names) > 25000:
            fail("unexpected ZIP entry count")
        total = 0
        for entry in entries:
            name = entry.filename.rstrip("/")
            path = PurePosixPath(name)
            if (not name or path.is_absolute() or ".." in path.parts or
                    str(path) != name or "\\" in name or "\x00" in name or
                    not (entry.filename in ("Payload/", "Payload/Madeira.app/") or
                         entry.filename.startswith(APP))):
                fail(f"unsafe or unexpected IPA path: {name}")
            mode = (entry.external_attr >> 16) & 0o170000
            if mode == stat.S_IFLNK:
                fail(f"symlink in IPA: {name}")
            if entry.file_size > 4 * 1024 ** 3:
                fail(f"unexpectedly large IPA entry: {name}")
            total += entry.file_size
            if total > 16 * 1024 ** 3:
                fail("unexpected IPA expanded size")
        print(f"PASS: {len(entries)} unique IPA entries have safe paths and sizes")

        info = plistlib.loads(archive.read(APP + "Info.plist"))
        schemes = {scheme for item in info.get("CFBundleURLTypes", [])
                   for scheme in item.get("CFBundleURLSchemes", [])}
        if (info.get("CFBundleDisplayName") != "GalacWin" or
                info.get("CFBundleIdentifier") != "com.galaczzy.galacwin" or
                info.get("CFBundleExecutable") != "Madeira" or
                "galacwin" not in schemes or "madeira" in schemes):
            fail("app identity, display name, executable or URL scheme differs")
        print("PASS: app identity and GalacWin URL scheme")

        required = ["Madeira", "Madeira.debug.dylib", "prefix-template.tar.gz",
                    "runtime-build.json", "licenses/LICENSE-MADEIRA-GPL-3.0.txt",
                    "licenses/LICENSE-MADEIRA-EXCEPTION.txt",
                    "licenses/LICENSE-GALACWIN-EXCEPTION.txt",
                    "x86_64-vcruntime/vcruntime140.dll", "i386-windows/ntdll.dll"]
        for relative in required:
            if APP + relative not in names:
                fail(f"missing app resource: {relative}")
        for source, bundled in [("COPYING", "licenses/LICENSE-MADEIRA-GPL-3.0.txt"),
                                ("LICENSE-EXCEPTION.md", "licenses/LICENSE-MADEIRA-EXCEPTION.txt"),
                                ("LICENSE-GALACWIN-EXCEPTION.md", "licenses/LICENSE-GALACWIN-EXCEPTION.txt")]:
            if archive.read(APP + bundled) != (ROOT / source).read_bytes():
                fail(f"bundled license differs from source: {source}")
        from importlib.util import module_from_spec, spec_from_file_location
        module_path = ROOT / "tools/security/check_prefix_template.py"
        spec = spec_from_file_location("check_prefix_template", module_path)
        prefix_check = module_from_spec(spec)
        spec.loader.exec_module(prefix_check)
        with archive.open(APP + "prefix-template.tar.gz") as stream:
            if sha256_stream(stream) != prefix_check.EXPECTED_SHA256:
                fail("bundled Wine prefix differs from the reviewed SHA-256")
        print("PASS: required resources, license texts and reviewed Wine prefix")

        manifest = json.loads(archive.read(APP + "runtime-build.json"))
        source_tree = subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD^{tree}"], text=True).strip()
        if manifest.get("schema") != 1 or manifest.get("tree") != source_tree:
            fail("embedded runtime manifest belongs to another source tree")
        contract = json.loads((ROOT / "tools/build/runtime-components.json").read_text())
        if set(manifest.get("components", {})) != set(contract):
            fail("runtime component list differs from the build contract")
        checked = 0
        for component in manifest["components"].values():
            for relative, digest in component["files"].items():
                if APP + relative not in names:
                    fail(f"missing runtime file: {relative}")
                with archive.open(APP + relative) as stream:
                    if sha256_stream(stream) != digest:
                        fail(f"runtime hash mismatch: {relative}")
                checked += 1
        for relative in contract["windows"]["prebuilt"]:
            if APP + relative in names:
                fail(f"diagnostic binary was packaged: {relative}")
        print(f"PASS: source tree and SHA-256 of {checked} runtime files; no diagnostic binaries")

        corrupt = archive.testzip()
        if corrupt:
            fail(f"IPA ZIP integrity failure: {corrupt}")
        print("PASS: full ZIP CRC integrity")


if __name__ == "__main__":
    main()
