# Procedencia observada del redistribuible Visual C++ x64

El 1 de noviembre de 2026 se descargó **sin ejecutar** el instalador desde
`https://aka.ms/vc14/vc_redist.x64.exe`, enlace x64 documentado en la
[página oficial de Microsoft](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist/).
La descarga se guardó sólo en el directorio local de revisión, fuera de este
repositorio.

| Campo | Resultado observado en Windows |
| --- | --- |
| Nombre | `vc_redist.x64.exe` |
| Tamaño | 18,731,856 bytes |
| Versión de archivo | `14.51.36247.0` |
| SHA-256 | `843068991DAAA1F73AD9F6239BCE4D0F6A07A51F18C37EA2A867E9BECA71295C` |
| Estado Authenticode | `Valid` |
| Firmante | `CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US` |
| Huella del certificado firmante | `1D77A9B9E8FE2075D9AD15123257FB90DB0DA4A1` |

La firma verificada y el hash identifican **esta copia** del instalador. El
enlace de Microsoft apunta a la versión más reciente y puede cambiar; un
futuro archivo con otro hash requiere revisión nueva.

El 2 de noviembre de 2026 se separaron los CAB del instalador y se extrajeron,
sin ejecutar el EXE, las 14 DLL AMD64 que `prepare-vcruntime.sh` empaquetaría.
Cada DLL contiene un encabezado PE AMD64, tiene firma Authenticode `Valid` con
firmante `Microsoft Windows Software Compatibility Publisher` de Microsoft
Corporation y coincide con el SHA-256 individual guardado en
[`tools/build/vc-redist-x64.sha256`](../tools/build/vc-redist-x64.sha256).
La firma de las 14 DLL mostró la misma huella de certificado:
`2650247AC56048BC7928663C02733D25898A1D6E`.

El script de compilación exige tanto el hash fijo del instalador como los 14
hashes individuales. No se han ejecutado estas DLL. La compilación permanece
bloqueada por otras revisiones pendientes descritas en `SECURITY.md`.
