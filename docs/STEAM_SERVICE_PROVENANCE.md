# Steam Client Service: procedencia del hash fijado

El 2 de noviembre de 2026 se consultó el paquete que ya fija
`app/Madeira/SteamRuntime.swift` para la instalación integrada de Steam:

- Origen: `https://client-update.akamai.steamstatic.com/bins_win32.zip.23e34a6d4b10596a44561a5100dac5585d2517da`
- Tamaño del ZIP: 59 544 006 bytes.
- SHA-256 del ZIP: `8b712b2a3412a9066b7725f4e1c5cef9a7ca5b187b6585a5b92d25d09df0ba62` (coincide con el valor fijado en el código).
- Entrada: `bin/SteamService.exe`, 2 950 296 bytes.
- SHA-256 de esa entrada: `72a406a6a2d3e282ab4b468ed8bfadf171fdd03a97969d6214a5da6fdb8dbd03`.

El archivo se leyó del ZIP para calcular el hash; no se ejecutó ni se
incorporó al repositorio o al IPA. La comprobación vincula el ejecutable con
el paquete fijado, pero no constituye por sí sola una verificación independiente
de su firma Authenticode ni una garantía de ausencia de código malicioso.

Esta comprobación por sí sola no basta para autorizar la ruta del servicio ya
registrado: su configuración podría apuntar a otro ejecutable o cambiar antes
de que el cliente lo arranque. Por ello, el parche de auditoría bloquea los
juegos marcados con ejecutables CEG y no inicia el gestor de servicios durante
la fase de instaladores. El segundo cliente DLL admitido por Dock (revisión
202609) tampoco tiene un hash de `SteamService.exe` documentado. Hay que
resolver ambas situaciones y probarlas antes de habilitar esa función.
