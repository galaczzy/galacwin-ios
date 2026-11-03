# Steam client dependency review

This review applies to the Valve client build selected by
`SteamRuntimeFiles.clientSHA256` and `madeira-dock` revision
`8c98616a68c45857c1b0fd1bc58268249b3aa3aa`. No Valve binary is stored in
this repository.

The package `bins_win32.zip.23e34a6d4b10596a44561a5100dac5585d2517da`
was downloaded over HTTPS from the fixed
`client-update.akamai.steamstatic.com` host. Its size was 59,544,006 bytes and
its SHA-256 matched the app's pin:
`8b712b2a3412a9066b7725f4e1c5cef9a7ca5b187b6585a5b92d25d09df0ba62`.
The separate `bins_win64_win32.zip` package also matched its pinned size and
SHA-256; it does not contain the client DLL or its two direct imports.

The PE import directory of `steamclient64.dll` contains these non-system,
same-directory DLLs. `vstdlib_s64.dll` also imports `tier0_s64.dll`.

| File | SHA-256 of extracted bytes |
| --- | --- |
| `steamclient64.dll` | `71b391fe9f3e2006cbc81a5c75eef3eb4186012deabfdb2c8b7e8d4850ecf640` |
| `tier0_s64.dll` | `af89cb6e94b20a5660d8f33427460fcd3b5e43e16b13372321d09cebab1288b8` |
| `vstdlib_s64.dll` | `9bb287b195f0a246f68ea462371178d9a2ebc23b03df295606ef189910aee2d2` |

The initial audited Dock patch checked the main DLL before a credential-bearing
session but did not check these two imports. A modified dependency could run
during `LoadLibraryExW` even with the main DLL hash unchanged. The updated
patch checks both exact files and holds their file and directory handles until
the session ends. A missing or modified dependency fails before loading the
main DLL. A 32-bit session is rejected because this build has no 32-bit
dependency allowlist.

This check covers the direct PE import graph. Valve's client can load other
components dynamically later; those components and any game executable still
need separate review. The client has not been signed in with a personal Steam
account on the iPad during this audit.
