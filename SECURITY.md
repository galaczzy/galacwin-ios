# Estado de seguridad de esta versión

Esta es una derivación local de Madeira, fijada inicialmente al commit
`c2c1b03a9e36ef986c980b9eae3c14d05a372db1`. Conserva su licencia y
atribuciones. **El IPA de auditoría v5 del commit
`8ead5c885e82fdd2cf7a5e1d08f243f7e019988a` pasó la verificación de
integridad y una pasada completa de ClamAV 1.5.4 sin detecciones de malware
conocido. Con PUA activadas sólo apareció la misma alerta ya investigada del
`kernel32.dll` ARM64EC de Wine, que no cambió desde v4. El usuario confirmó que
Sideloadly instaló v5, que la biblioteca abrió sin Wi-Fi y sin avisos, que la
prueba aislada JIT devolvió 42 y que Notepad respondió en el escritorio Wine.
Juegos y uso con cuentas personales siguen sin probarse.** Una revisión de código,
un resultado antivirus y una prueba en dispositivo no pueden demostrar ausencia
absoluta de malware. El artefacto público de Actions contiene únicamente un
IPA cifrado para una clave guardada fuera del repositorio.

En una apertura separada de varios minutos en la biblioteca con Wi-Fi, sin
cuentas ni descargas, el usuario activó el Informe de privacidad de las apps
de iPadOS. GalacWin apareció allí sin dominios registrados. Esto sólo describe
lo que mostró ese informe en esa prueba; no es una captura completa del tráfico
ni demuestra ausencia de código malicioso.

El commit [`e9b54b1`](https://github.com/galaczzy/galacwin-ios/commit/e9b54b1f4784576f94a92505f5429caf9adc9897)
añadió una comprobación de tamaño y SHA-256 para las imágenes de desarrollo que
el ayudante JIT entrega a StikJIT. La [ejecución de Actions #41404266066](https://github.com/galaczzy/galacwin-ios/actions/runs/41404266066)
compiló el ayudante con Xcode y terminó correctamente. Esta ejecución no creó
un IPA, y el IPA de auditoría instalado proviene de un commit anterior. La
dependencia `idevice` precompilada de StikJIT aún requiere revisión.

La [compilación de auditoría v2 #41405450209](https://github.com/galaczzy/galacwin-ios/actions/runs/41405450209)
del commit `37f8060853b30f3dbd6b2a187e3d275c2aba47aa` terminó correctamente.
El nuevo IPA incorpora la comprobación DDI y su SHA-256 coincide con el que
registró el runner antes del cifrado. El verificador independiente pasó todas
sus comprobaciones. ClamAV 1.5.4 con la base `daily` 28172 examinó 1.11 GiB:
la pasada de malware terminó `OK` y la pasada PUA con búsqueda de todas las
coincidencias marcó sólo el `kernel32.dll` de Wine con la misma firma anterior.
El usuario confirmó que Sideloadly instaló el IPA v2 y que GalacWin llegó a la
biblioteca con Wi-Fi apagado, sin avisos. **JIT sigue sin aprobarse.** Esta
prueba de interfaz no inspeccionó el paquete vuelto a firmar ni ejercitó juegos
o cuentas.

En una prueba adicional con Wi-Fi y sin cuentas ni JIT, el usuario indicó que
GalacWin v2 no apareció en «Actividad de red de las apps» de iPadOS tras varios
minutos. Esto es un resultado inconcluso del informe, no una prueba de ausencia
de tráfico. La observación anterior de «sin dominios registrados» pertenecía
al IPA v1.

El [IPA de auditoría v3](https://github.com/galaczzy/galacwin-ios/actions/runs/41475453651)
del commit `d9cf3bef8d12205892f6ea89e8f9462bfab87ad9` reconstruyó StikJIT y
su dependencia `idevice` desde fuentes fijadas en la misma ejecución. El
SHA-256 del IPA local coincide con el registrado por el runner:
`2609872472b7054069514894700ca2cb9c779765c94f89c594b9546e107e6192`.
La verificación estática independiente aprobó sus 1 432 entradas; ClamAV 1.5.4
no detectó malware conocido en una pasada completa sin PUA. Con PUA activadas
señaló sólo la misma firma `PUA.Win.Packer.Embedpe-3` del `kernel32.dll` de Wine
que en v2. El usuario confirmó que Sideloadly instaló v3 y que GalacWin llegó
a la biblioteca en un iPad Pro M5 con Wi-Fi apagado, JIT desactivado y sin
avisos. Estos resultados no prueban que el código o sus dependencias estén
libres de malware ni validan la ejecución de código JIT.

En una prueba posterior, el usuario confirmó que LocalDevVPN tenía las
direcciones locales esperadas y estaba conectado. El emparejamiento integrado
persistió tras reiniciar GalacWin. El primer «Check setup» quedó procesando
más de diez minutos; tras reiniciar la app, el segundo terminó correctamente.
«Enable JIT» mostró «Built-in JIT is attached». Es una observación de la
interfaz comunicada por el usuario: todavía no se ha probado la ejecución de
código JIT ni de juegos, ni se ha instrumentado el dispositivo para validar
el contenido DDI o el tráfico.

El [IPA de auditoría v4](https://github.com/galaczzy/galacwin-ios/actions/runs/41492574330)
del commit `806f3d2494d63c435c43420dcb7d4dd41a5d3c5b` añadió un botón manual
para ejecutar una función ARM64 fija que devuelve 42. Su SHA-256 local,
`24211e894ebc36fe191fa607ed7b731dcd10373dd7e037ec0fd9cb253fcf376b`,
coincidió con el registrado por el runner antes de cifrarlo. El verificador
independiente aprobó 1 432 entradas y los hashes de 577 archivos del runtime.
ClamAV examinó 1.11 GiB: la pasada de malware terminó sin detecciones y la
pasada PUA señaló sólo `PUA.Win.Packer.Embedpe-3`; el `kernel32.dll` extraído
activó la misma firma y conserva el hash de v3. Una revisión de seguridad del
cambio v4 terminó sin hallazgos reportables en su archivo modificado. El
usuario informó que Sideloadly instaló v4, que la biblioteca abrió sin Wi-Fi
y sin avisos, que LocalDevVPN y el emparejamiento estaban listos, y que «Check
setup» y «Enable JIT» terminaron correctamente. Al pulsar una vez «Test JIT
execution», GalacWin mostró «JIT execution passed: the generated function
returned 42.» Esta observación valida una función generada en esa sesión; no
valida juegos, otras rutas de JIT, el paquete vuelto a firmar ni ausencia
absoluta de malware.

En una prueba funcional posterior con el mismo IPA v4, el usuario informó que
«Desktop → Play» abrió el escritorio de Wine, que podía mover el cursor y que
«Start → Run» abrió el `notepad.exe` incluido en el paquete. Escribió una frase
de prueba sin guardarla; el texto apareció y la ventana siguió respondiendo.
La app avisó que el pool JIT de esa sesión se redujo a 608 MB y que juegos
grandes podrían no cargar. El código emite ese aviso cuando la asignación fue
menor a la solicitada; no es una detección de malware. Esta prueba no valida
juegos, rendimiento ni todas las funciones del escritorio.

Una revisión completa del submódulo fijado `madeira-dock` encontró tres
problemas condicionados: una DLL de Steam desconocida podía cargarse antes de
rechazar una sesión; el instalador del servicio de Steam sólo comprobaba si
existía su ejecutable; y el informe del escáner de privacidad repetía el texto
encontrado. El parche de auditoría exige un hash de cliente reconocido antes
de cargar la DLL con una credencial, comprueba y mantiene abiertos los
componentes de la ruta durante la carga, y oculta tanto el texto como el nombre
del archivo en el informe de privacidad. La ruta CEG queda bloqueada porque un
servicio ya registrado puede apuntar a otro ejecutable o cambiar su
configuración antes de arrancar; el paso previo a instaladores tampoco inicia
el gestor de servicios. Esto limita juegos e instaladores que requieren ese
servicio. La procedencia del ejecutable de servicio investigado está en
[docs/STEAM_SERVICE_PROVENANCE.md](docs/STEAM_SERVICE_PROVENANCE.md). El IPA v4
instalado antes de esta revisión no incorpora ese parche. El [IPA v5 de
auditoría](https://github.com/galaczzy/galacwin-ios/actions/runs/41526771615)
sí lo incorpora: su SHA-256 local coincide con el registrado por el runner,
`19228d7c70c56970a63b0945e3ad035a1e29ec372d28f1f99809dbb4a403a416`.
El verificador estático aprobó 1 432 entradas y los hashes de 577 archivos del
runtime. ClamAV examinó 1,11 GiB sin detecciones de malware conocido; con PUA
activadas señaló sólo la firma anterior. El usuario informó que Sideloadly
instaló v5, que llegó a la biblioteca sin Wi-Fi y sin avisos, que LocalDevVPN
y el emparejamiento estaban listos, que «Check setup» terminó correctamente,
que «Enable JIT» se adjuntó y que la prueba de ejecución devolvió 42. También
abrió el escritorio Wine y usó Notepad sin guardar un archivo. Apareció el
mismo aviso de memoria JIT pequeña de v4. Falta probar juegos, cuentas
personales, la ruta de Dock con credenciales y completar el resto de la
auditoría.

## Controles aplicados

- El registro de inicio y el puente de Wine enumeran claves de `madeira.cfg`
  y nombres de variables de entorno sin guardar sus valores.
- La restauración de partidas limita el número de entradas, el tamaño de cada
  entrada y el tamaño total declarado antes de descomprimir.
- El parser de manifiestos de Steam rechaza encabezados de menos de 8 bytes.
- El parser limita tamaños de archivos, depots y chunks; comprueba sumas,
  conversiones a UInt32 y que cada chunk quepa dentro de su archivo. El
  cambio compiló en macOS y pasó una prueba aislada de descarga.
- Los chunks nuevos de Steam se comparan con el SHA-1 del manifiesto antes de
  escribirse.
- La preparación del runtime de Visual C++ exige un SHA-256 aprobado del
  redistribuible incluso si ya existe una copia local. Un valor distinto
  detiene la compilación.
- Se comprobó una descarga del redistribuible x64 desde el enlace documentado
  por Microsoft: firma Authenticode válida de Microsoft Corporation y SHA-256
  registrado en [docs/VC_REDIST_PROVENANCE.md](docs/VC_REDIST_PROVENANCE.md).
  Ese archivo no se ejecutó ni se incorporó al repositorio. Sus 14 DLL AMD64
  también tienen firma válida de Microsoft y SHA-256 individuales fijados en
  `tools/build/vc-redist-x64.sha256`.
- GitHub Actions sólo inicia la compilación manualmente. `audit_build=true`
  permite una prueba aislada en el repositorio público y publica únicamente un
  IPA cifrado con age. La clave privada de descifrado queda en la PC del usuario;
  sin ese modo, el trabajo de seguridad exige
  `SECURITY_BUILD_APPROVED=true`. Este valor debe activarse únicamente después
  de completar la lista de controles.
- Las acciones de checkout, caché y artefactos del flujo están fijadas a
  commits concretos; checkout no conserva la credencial de Git para los
  scripts posteriores.
- Las cinco herramientas Python usadas por Mesa D3D12 están fijadas a ruedas
  concretas para Python 3.13/macOS arm64 con SHA-256 obligatorio; el flujo
  selecciona esa versión de Python. La resolución completa se probó con
  `pip download --require-hashes` sin instalar ni ejecutar las ruedas.
- Las herramientas Python de Mesa para iOS también se instalan desde ruedas
  fijadas con SHA-256; sus trabajos de CI seleccionan Python 3.13.
- La compilación de LLVM exige el commit exacto de la etiqueta de versión
  15.0.7 y rechaza cambios inesperados en su checkout antes de invocar CMake;
  véase [docs/LLVM_PROVENANCE.md](docs/LLVM_PROVENANCE.md).
- El IPA final se crea y verifica en la ejecución actual de Actions. El flujo
  ya no restaura ni publica archivos IPA completos desde la caché.
- Los 22 ejecutables de diagnóstico de Windows enumerados como `prebuilt` en
  `tools/build/runtime-components.json` se excluyen del IPA. El validador
  rechaza un paquete que todavía contenga cualquiera de ellos.
- Los diez blobs Git del framework StikJIT coinciden byte por byte con el ZIP
  publicado por StikDebug para la versión 1.9.0; véase
  [docs/STIKJIT_PROVENANCE.md](docs/STIKJIT_PROVENANCE.md).
- El ayudante JIT del código actual sólo entrega a StikJIT imágenes DDI cuyo
  tamaño y SHA-256 coinciden con un conjunto fijado a un commit concreto;
  véase [docs/JIT_DDI_PROVENANCE.md](docs/JIT_DDI_PROVENANCE.md). Esto está
  presente en los IPA v2 y v3, pero no en el IPA v1 descrito al final.
- El prefijo Wine incluido ya no contiene `chcp.com` ni el instalador MSI. Se
  verificó que las otras 136 entradas conservaran su contenido y metadatos;
  el compilador exige su SHA-256 aprobado y rechaza rutas, enlaces y tipos de
  archivo peligrosos. Véase [docs/PREFIX_PROVENANCE.md](docs/PREFIX_PROVENANCE.md).

## Pendiente antes de considerar el IPA apto para uso personal

1. Revisar los 24 submódulos recursivos en sus commits fijados. La copia de la
   auditoría inicial y el ZIP del proyecto principal no contenían sus cuerpos.
   El runner sí descargó y compiló los submódulos, lo cual no equivale a una
   auditoría de todo su código.
2. Establecer procedencia independiente de los demás binarios precompilados y
   los archivos restantes del prefijo comprimido, y ampliar la auditoría del
   código fuente de StikJIT y sus dependencias. La etiqueta 1.9.0 de StikJIT
   incluye un archivo `idevice` ya compilado; el IPA v3 lo sustituyó por uno
   reconstruido desde fuentes fijadas. El código actual llena y verifica la
   caché DDI antes de invocar StikJIT. Los IPA v2, v3 y v4 incorporan esa
   protección. La prueba aislada JIT de v4 pasó en el dispositivo, pero falta
   probar cargas de juego y otros recorridos de JIT; véanse
   [docs/STIKJIT_PROVENANCE.md](docs/STIKJIT_PROVENANCE.md) y
   [docs/JIT_DDI_PROVENANCE.md](docs/JIT_DDI_PROVENANCE.md). El inventario
   `security/upstream-binaries.csv` sólo registra hashes de la copia.
3. Revisar las demás descargas de CI y validar el flujo completo en un runner
   aislado. Las acciones de GitHub y las herramientas Python de Mesa D3D12
   ya están fijadas, pero otros gestores de paquetes y archivos descargados
   aún requieren revisión.
4. Autenticar criptográficamente el manifiesto de Steam. El parser ya exige
   identidad de depot/GID, estructura y cobertura de chunks; las rutas de
   escritura y enlaces simbólicos se ejercitaron con una prueba aislada en
   macOS. La prueba también rechaza un diario falsificado y comprueba que una
   actualización fallida no trunque un archivo existente. Esto no sustituye
   la autenticidad criptográfica del manifiesto.
5. Cifrar y autenticar el transporte de Metal remoto en `dxmt` y en su
   prototipo antes de exponerlo en una red; el lanzador de prueba ahora usa
   loopback por defecto, pero el cliente de la app aún usa TCP sin cifrar
   cuando se configura `remote`.
6. Obtener, si se desea, confirmación del proveedor sobre la alerta PUA de
   ClamAV y ampliar las pruebas en el iPad con datos de prueba antes de
   introducir cuentas personales. La instalación, la apertura sin Wi-Fi y la
   ejecución de una función JIT fija fueron confirmadas por el usuario, sin
   instrumentación independiente del paquete vuelto a firmar por Sideloadly.
   La compilación macOS/Xcode de auditoría, la verificación estática y una
   pasada antivirus sin firmas de malware terminaron correctamente; ninguna
   de estas pruebas demuestra seguridad de comportamiento en todas las
   funciones.

La app ejecuta juegos de Windows dentro de su propio proceso. Un juego o
instalador malicioso sigue siendo un riesgo independiente de la procedencia del
IPA. No se han ejecutado juegos ni instaladores de terceros en esta etapa.

## Evidencia del IPA de auditoría

- Commit de compilación: `c45f89bb0e4388ac2b0a0bffe9254b241fe9b7c2`.
- SHA-256 del IPA: `2934828b5d38ad4ba33e73fb32f84b9e220f32294a582f2a76e254a4c41159ba`.
- El SHA-256 del IPA descifrado coincide con el registro del runner. El
  verificador independiente confirmó rutas seguras y únicas en 1432 entradas,
  identidad de GalacWin, textos de licencia del commit, prefijo Wine fijado,
  577 archivos de runtime contra sus hashes y CRC completo del ZIP.
- El archivo IPA sin cifrar no se publicó como artefacto de GitHub.
- ClamAV 1.5.4 con base oficial actualizada escaneó 1.11 GiB de contenido del
  IPA. Con firmas de malware y PUA activas marcó únicamente
  `Payload/Madeira.app/arm64ec-windows/kernel32.dll` como
  `PUA.Win.Packer.Embedpe-3`; una pasada completa con las firmas PUA
  desactivadas terminó `OK`, cero archivos infectados. El DLL coincide con el
  hash del manifiesto generado desde Wine en el commit fijado
  `df1c5ea51e194937ac204bc3120922dc56a61bec`. Su encabezado de máquina
  `0x8664` y las secciones híbridas son compatibles con un PE ARM64EC; esto
  hace plausible una detección heurística. El DLL rastreado antes de la
  compilación tiene un hash distinto, pero activa la misma firma; en ambos la
  secuencia coincidente contiene relleno seguido de `KERNEL32.`. El código
  fuente de `dlls/kernel32` difiere de Wine 11.4 solo en `heap.c`,
  `kernel32.spec` y `sync.c`: 17 líneas añadidas y 29 eliminadas para ajustes
  de memoria y funciones de reloj. El PE importa únicamente `kernelbase.dll`
  y `ntdll.dll`. La [documentación de ClamAV](https://docs.clamav.net/faq/faq-pua.html)
  advierte que sus reglas PUA pueden
  producir más falsos positivos. `sigtool` localizó la regla en el mismo
  desplazamiento 335796 en los dos DLL: ceros seguidos de `KERNEL32.dll` y
  nombres de funciones. El DLL reconstruido solo tiene un encabezado `MZ`;
  los bytes fuera de las secciones PE son símbolos COFF y relleno. Esta alerta
  PUA concreta se considera un falso positivo con alta confianza, pero la
  evidencia no certifica el resto del IPA.

## Evidencia local

`security/upstream-binaries.csv` registra la base inicial: 599 archivos
presentes y un ejecutable de prueba ausente (`tests/x64/asmconf-x64.exe`).
Ese ejecutable se elimina del proyecto derivado porque no se pudo inspeccionar.
El script `tools/security/inventory_binaries.py` genera un inventario nuevo de
los archivos actualmente rastreados, sin ejecutarlos. Estos hashes permiten
comparar cambios; la ausencia del ejecutable impide tratar el checkout inicial
como íntegro respecto del commit de origen.
