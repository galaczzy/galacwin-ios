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
