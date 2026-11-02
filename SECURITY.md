# Estado de seguridad de esta versión

Esta es una derivación local de Madeira, fijada inicialmente al commit
`c2c1b03a9e36ef986c980b9eae3c14d05a372db1`. Conserva su licencia y
atribuciones. **Sólo se permite una compilación de auditoría aislada en GitHub
Actions, sin cuentas ni secretos personales. El artefacto de auditoría contiene
únicamente un IPA cifrado para la clave guardada fuera del repositorio. Todavía no
está aprobada para instalar ni usar con cuentas personales.** Una revisión de
código y un resultado de antivirus no pueden demostrar ausencia absoluta de malware.

## Controles aplicados

- El registro de inicio y el puente de Wine enumeran claves de `madeira.cfg`
  y nombres de variables de entorno sin guardar sus valores.
- La restauración de partidas limita el número de entradas, el tamaño de cada
  entrada y el tamaño total declarado antes de descomprimir.
- El parser de manifiestos de Steam rechaza encabezados de menos de 8 bytes.
- El parser limita tamaños de archivos, depots y chunks; comprueba sumas,
  conversiones a UInt32 y que cada chunk quepa dentro de su archivo. El
  cambio aún requiere compilación y pruebas en macOS.
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
- El prefijo Wine incluido ya no contiene `chcp.com` ni el instalador MSI. Se
  verificó que las otras 136 entradas conservaran su contenido y metadatos;
  el compilador exige su SHA-256 aprobado y rechaza rutas, enlaces y tipos de
  archivo peligrosos. Véase [docs/PREFIX_PROVENANCE.md](docs/PREFIX_PROVENANCE.md).

## Pendiente antes de un IPA de prueba

1. Revisar los 24 submódulos recursivos en sus commits fijados. Se
   descargaron localmente sin ejecutarlos; la copia de la auditoría inicial
   no los contenía y el archivo ZIP del proyecto principal tampoco incluye
   sus cuerpos.
2. Establecer procedencia independiente de los demás binarios precompilados,
   los archivos restantes del prefijo comprimido, y reconstruir o auditar el código fuente
   de StikJIT. La coincidencia con su ZIP oficial establece el origen del
   framework, pero no demuestra ausencia de malware. La etiqueta 1.9.0 de
   StikJIT enlaza un archivo `idevice` ya compilado y descarga imágenes DDI
   desde una rama mutable sin hashes fijados; véase
   [docs/STIKJIT_PROVENANCE.md](docs/STIKJIT_PROVENANCE.md). El inventario
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
6. Construir en un macOS/Xcode controlado, inspeccionar el IPA resultante y
   probarlo en un dispositivo y cuentas de prueba antes de introducir cuentas
   personales. El usuario no necesita poseer una Mac: un runner macOS de
   GitHub Actions puede compilar cuando estos controles estén listos.

La app ejecuta juegos de Windows dentro de su propio proceso. Un juego o
instalador malicioso sigue siendo un riesgo independiente de la procedencia del
IPA. No se han ejecutado esos binarios ni se ha generado un IPA en esta etapa.

## Evidencia local

`security/upstream-binaries.csv` registra la base inicial: 599 archivos
presentes y un ejecutable de prueba ausente (`tests/x64/asmconf-x64.exe`).
Ese ejecutable se elimina del proyecto derivado porque no se pudo inspeccionar.
El script `tools/security/inventory_binaries.py` genera un inventario nuevo de
los archivos actualmente rastreados, sin ejecutarlos. Estos hashes permiten
comparar cambios; la ausencia del ejecutable impide tratar el checkout inicial
como íntegro respecto del commit de origen.
