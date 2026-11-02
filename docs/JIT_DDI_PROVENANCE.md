# Imágenes de desarrollo para JIT

El ayudante JIT verifica tamaño y SHA-256 de cada archivo antes de entregarlo a
StikJIT. Las descargas usan el commit fijo
[`e2aaeac89ca8fa56c2fa1f144d182994e07a525b`](https://github.com/doronz88/DeveloperDiskImage/tree/e2aaeac89ca8fa56c2fa1f144d182994e07a525b/PersonalizedImages)
de `doronz88/DeveloperDiskImage`. Los archivos no se incorporan a Git ni al IPA.
Los valores siguientes se obtuvieron descargando los archivos de ese commit y
calculando SHA-256 localmente el 2 de noviembre de 2026.

## iPadOS 26.4 y posteriores: `Xcode_iOS_DDI_Cryptex`

| Archivo | Bytes | SHA-256 |
| --- | ---: | --- |
| `BuildManifest.plist` | 804946 | `27385d7582b03b36bb3104e22b520aee0c47d72fecb4e8ecfe12ef5d966c7012` |
| `Image.dmg` | 15895040 | `873097f695a8b9734e2abc54f795a8874d40ff6fd11208ecb01ef29534c7c176` |
| `Image.dmg.trustcache` | 1895 | `f7f21986074eee03a215aca16ecfc78d6bf183600d8a0d2fb691f9896782e6f0` |
| `Image.dmg.cryptex_info` | 430 | `edf49aef55aacc063d4d7be05b713bb545ce2993b3f62bcc15eccd75e610ee6c` |
| `Image.dmg.root_hash` | 229 | `3543fad2805b88119695c417e12679380b3b5a2742994bbcc839c8e2de5d7302` |

## iPadOS 26.0–26.3: `Xcode_iOS_DDI_Personalized`

| Archivo | Bytes | SHA-256 |
| --- | ---: | --- |
| `BuildManifest.plist` | 801505 | `8edd4a2f4f4ef1fbd7bfe49785d8badc673d1395d1d94d85b132ca8ab5ecaf54` |
| `Image.dmg` | 15733248 | `05fd807da5e19f030fa4941f24800c965c6c77982ab572dd5d1ef778fb69f9ca` |
| `Image.dmg.trustcache` | 1895 | `36af60889ff5a737874a26daeb8e1a0139ebfebec6ec2e4d8f6a3c1bf1dce35c` |

Se rechaza cualquier descarga o archivo almacenado que no coincida. Un cambio
legítimo de estas imágenes requiere revisar los nuevos archivos, fijar un
commit nuevo, actualizar los hashes y compilar otra versión. Esta comprobación
evita la sustitución silenciosa desde una rama mutable, pero no demuestra que
las imágenes o el resto de StikJIT estén libres de fallos o código malicioso.
