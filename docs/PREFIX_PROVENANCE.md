# Procedencia y límites del prefijo Wine incluido

El repositorio de origen incluyó `app/Madeira/prefix-template.tar.gz` como
archivo precompilado. Su SHA-256 antes de esta revisión era
`7fe642c4e07910d5956e43bac243e01fd079c271391f22283dd1e377e876cc9f`.
Se inspeccionó con `tarfile` sin extraerlo ni ejecutar su contenido.

Contenía 138 entradas: 106 directorios, 32 archivos regulares y ningún
enlace. Dos archivos regulares podían ejecutarse o instalarse:

| Ruta dentro del archivo | SHA-256 del contenido |
| --- | --- |
| `prefix/drive_c/windows/system32/chcp.com` | `3a46d175e201afd0e5f8d3da8d37dc44ae10e3f68f91bce902adb8de1c961de1` |
| `prefix/drive_c/windows/Installer/81cd.msi` | `e08b4e82e28a65eb3107e3f1f302b3374ff277d51a60e513380085eff76a0524` |

Se creó una copia sin esas dos entradas. Se compararon nombres, tipos, modos
Unix y SHA-256 del contenido de cada una de las otras 136 entradas con la
copia original. Ninguna otra entrada cambió. La copia aprobada tiene SHA-256
`66ebda0615ea780cd3f8c4c0744553a539e86bd4c97fc338355e62f7d8fdba56`.

`tools/check-prefix-template.sh` comprueba ese hash y además analiza el
archivo sin extraerlo. Rechaza rutas fuera de `prefix/`, duplicados, enlaces,
archivos especiales, extensiones ejecutables o instalables, bits de ejecución
y tamaños excesivos. `tools/build-prefix-snapshot.sh` elimina también esas
extensiones si se regenera la plantilla. Una plantilla regenerada requiere
revisión y actualización deliberada del hash aprobado.

La plantilla restante contiene archivos de registro, fuentes, configuración y
datos de Wine. Su procedencia a nivel de fuente aún no está demostrada. El
registro de desinstalación de Wine Mono menciona el MSI eliminado; por eso
se debe comprobar en el dispositivo si su ausencia afecta esa operación.
Esta inspección de contenido y el hash fijado no prueban ausencia de malware.
