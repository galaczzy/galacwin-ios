# Obtaining the Microsoft Visual C++ runtime DLLs

Games built with MSVC need the Visual C++ runtime. Those DLLs are authored by
Microsoft and are **not** redistributable under this project's license, so they
are not committed here. You supply them yourself.

Fourteen files are expected in `app/Madeira/x86_64-vcruntime/`, the twelve
C++ runtime DLLs and MFC's two from the same package (madeira-bcd,
2026-10-09: Horizon Zero Dawn imports mfc140.dll; `env.MADEIRA_MFC = 0` keeps
MFC out of a game's system32):

```
concrt140.dll              msvcp140_codecvt_ids.dll   vcruntime140.dll
msvcp140.dll               vcamp140.dll               vcruntime140_1.dll
msvcp140_1.dll             vccorlib140.dll            vcruntime140_threads.dll
msvcp140_2.dll             vcomp140.dll               mfc140.dll
msvcp140_atomic_wait.dll                              mfc140u.dll
```

## How to get them

The helper accepts only the independently reviewed Microsoft package recorded
in `docs/VC_REDIST_PROVENANCE.md`. It checks the package SHA-256 and all 14
individual DLL hashes. A changed Microsoft download stops extraction:

```sh
./tools/fetch-vcruntime.sh
```

Or manually download the official x64 redistributable from Microsoft
(`VC_redist.x64.exe`) and extract it. On macOS, 7-Zip can do this:

```sh
brew install sevenzip
7zz x VC_redist.x64.exe -o/tmp/vcredist
7zz x /tmp/vcredist/.rsrc/1033/CABINET/*.cab -oapp/Madeira/x86_64-vcruntime
```

Exact layout varies by redistributable version. Manual extraction must undergo
the same publisher and hashes in `tools/build/vc-redist-x64.sha256` before
those DLLs enter an IPA. The goal is the fourteen approved files above,
**byte-for-byte as Microsoft shipped them**.

## Do not modify them

Microsoft's redistribution permission covers the eligible files *unmodified*.
In particular, do not strip Authenticode signatures. You can check that the files
still carry their signature payload using the host test:

```sh
python3 tests/host/check-vcruntime.py --strict
```

A file whose certificate offset equals its own length has had the signature
truncated off and is no longer an unmodified Microsoft binary.
