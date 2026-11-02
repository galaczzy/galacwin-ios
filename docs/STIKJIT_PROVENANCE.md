# Procedencia del framework StikJIT incluido

El 1 de noviembre de 2026 se descargó **sin ejecutarlo** el archivo
`StikJIT.xcframework.zip` de la [versión oficial 1.9.0 de
StikDebug/StikJIT](https://github.com/StikDebug/StikJIT/releases/tag/1.9.0).
El ZIP tiene 1,748,460 bytes y SHA-256
`806664393770c68e75f2b6429955bfdd88cfaad09fec2ba70f8ed615ff90c060`,
el mismo hash ya citado en `docs/JIT.md`.

Se compararon los **diez archivos** del ZIP con los diez blobs rastreados en
Git bajo `app/Frameworks/StikJIT.xcframework/`; cada par coincide byte por
byte. El ejecutable también coincide con el archivo del checkout de Windows.
Los otros ocho archivos de texto/metadatos tienen CRLF en ese checkout y LF en
Git y en el ZIP; al normalizar los saltos de línea coinciden.

Esta comparación establece que el framework rastreado proviene de ese ZIP
publicado. No prueba que el proyecto de origen esté libre de código malicioso,
ni que su binario sea reproducible a partir del código fuente. La revisión de
StikJIT y de sus dependencias sigue pendiente antes de aprobar un IPA.

El 2 de noviembre de 2026 se obtuvo, sin compilarlo, el código de la etiqueta
`1.9.0` (`32287268fa5824f9edce4cb359f5833ce0cf7b00`). Su proyecto enlaza
`idevice/libidevice_ffi.a`, un archivo estático ya compilado de 57,017,464
bytes que forma parte del repositorio de StikJIT. El flujo de compilación de
esa versión no reconstruye ese archivo desde el código fuente de `idevice`;
la coincidencia del framework con el ZIP oficial no cierra esa brecha de
procedencia.

Se calculó el SHA-256 del archivo estático de la etiqueta 1.9.0:
`4db23fe1d342927b9480bb9a8577f219994365621dc28aa0018e23ea1990ecc8`.
El contenedor `ar` tiene 901 miembros, entre ellos objetos de `idevice_ffi`,
`idevice`, Rust y sus dependencias. Un examen de cadenas encontró referencias
esperables a servicios de Apple y a `127.0.0.1`, pero las cadenas visibles no
permiten descartar funciones ocultas ni vincular el binario a un commit de
fuente. Esta inspección no cambia el estado de seguridad pendiente.

El [proyecto original `idevice`](https://github.com/jkcoxson/idevice) publica
instrucciones para compilar su FFI para iOS desde Rust en su
[`justfile`](https://github.com/jkcoxson/idevice/blob/master/justfile). Una
sustitución futura deberá fijar commit y toolchain, reconstruir la biblioteca y
el framework StikJIT, revisar las dependencias, comprobar la interfaz y probar
JIT en un dispositivo. El IPA de auditoría v2 todavía incluye el framework
precompilado de StikJIT 1.9.0.

También se observó que StikJIT obtiene imágenes de desarrollo desde la rama
mutable `main` de `doronz88/DeveloperDiskImage` y su descargador comprueba el
estado HTTP, pero no fija hashes de los archivos antes de guardarlos. Se
necesita revisar esta ruta y el proceso de montaje antes de habilitar JIT
integrado para la prueba con una cuenta o dispositivo personal. Ninguna de
estas observaciones demuestra por sí sola que el framework sea malicioso.

## Reconstrucción experimental desde fuentes fijadas

En la rama `jit-source-build` se reconstruyó el archivo FFI de `idevice` desde
el commit `d32c8189c51c2789496b0768039419c3705498c3` de la etiqueta
`v0.1.68`, con Rust 1.99.0, `Cargo.lock`, destino `aarch64-apple-ios` y las
funciones `full,rustcrypto`. Se desactivó la opción `obfuscate` para que las
cadenas de servicio no se oculten. La biblioteca reconstruida sustituyó al
archivo precompilado de StikJIT 1.9.0 antes de generar el proyecto y compilar
el framework con Xcode 27.1. El ayudante JIT de GalacWin compiló contra el
framework resultante en la [ejecución #41472357918](https://github.com/galaczzy/galacwin-ios/actions/runs/41472357918).

La ejecución registró SHA-256
`f23e822f82d96ab7102c9fcbefe801f4ae8531ba7300b1110e532a14b804c54f`
para `libidevice_ffi.a` y
`cedba2339d83fdb77d842655005667eedd15508c611dbd2a0eb4693b0b9d6b89`
para el binario StikJIT. El ZIP del artefacto descargado coincidió con el
digest de GitHub `3e827a5809fd8b47f71b90a3c3522fdc7c7e3a0f77b2aeb26f13770e8ea5f7bd`;
sus diez entradas pasaron la comprobación CRC. Esta es evidencia de que
**se puede reconstruir y enlazar**, no una prueba funcional de JIT ni una
auditoría completa de sus dependencias.

El flujo experimental se trasladó a `tools/build/build-stikjit-source.sh` y el
IPA de auditoría v3 reconstruyó el framework en la misma ejecución. El script
fija los commits de `idevice` y StikJIT, exige
`cargo --locked` y verifica por SHA-256 el ZIP de XcodeGen 2.46.0 antes de
extraerlo y ejecutarlo. Ese ZIP se descargó sin ejecutarlo en Windows y su
hash coincidió con el digest de la [versión oficial de
XcodeGen](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0):
`4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`.
El flujo de IPA compara el binario reconstruido con el contenido del IPA antes
de cifrarlo. El IPA v2 instalado anteriormente conserva la versión
precompilada original.

La [ejecución de comprobación #41474582986](https://github.com/galaczzy/galacwin-ios/actions/runs/41474582986)
ejecutó el script compartido y terminó correctamente. El ZIP del artefacto
coincidió con el digest de GitHub
`b9425940c28b7495e4919321d6c05ffa064f23cd971913c10f7c1a4a10c08e1c`.
La biblioteca FFI, su encabezado y los diez archivos del framework resultaron
idénticos byte por byte a los de la ejecución #41472357918. Esto mejora la
trazabilidad de esta reconstrucción concreta; no demuestra que todo el código
fuente o sus dependencias sean seguros.

## IPA de auditoría v3

La [compilación #41475453651](https://github.com/galaczzy/galacwin-ios/actions/runs/41475453651)
del commit `d9cf3bef8d12205892f6ea89e8f9462bfab87ad9` terminó correctamente.
El SHA-256 del IPA antes de cifrarlo, registrado por el runner, es
`2609872472b7054069514894700ca2cb9c779765c94f89c594b9546e107e6192`;
el mismo valor se obtuvo del archivo descifrado localmente. El binario StikJIT
dentro de ese IPA tiene SHA-256
`cedba2339d83fdb77d842655005667eedd15508c611dbd2a0eb4693b0b9d6b89`,
igual al reconstruido en el runner y en las dos ejecuciones de prueba.

El verificador independiente aprobó 1 432 entradas del IPA, sus rutas y CRC,
la identidad, el prefijo y los hashes de 577 archivos de runtime. ClamAV 1.5.4,
con bases oficiales actualizadas, examinó 1.11 GiB sin detectar firmas de
malware conocido en la pasada completa sin PUA. Con PUA activadas señaló
únicamente `PUA.Win.Packer.Embedpe-3` en el `kernel32.dll` de Wine, idéntico al
de v2. La prueba de instalación y apertura de v3 en el iPad sigue pendiente.
La reconstrucción y estas comprobaciones no demuestran ausencia absoluta de
malware ni validan la función JIT.
