# LLVM 15.0.7 para la compilación iOS

El script `tools/build/build-llvm-ios.sh` obtiene `llvm-project` de
`https://github.com/llvm/llvm-project.git` usando la etiqueta
`llvmorg-15.0.7`. El 2 de noviembre de 2026, la consulta de referencias
remotas devolvió:

```text
d2b30c38ff585ddec8fe05fac734c0bb2a6bacc3  refs/tags/llvmorg-15.0.7
8dfdcc7b7bf66834a761bd8de445840ef68e4d1a  refs/tags/llvmorg-15.0.7^{}
```

La segunda línea es el commit al que apunta la etiqueta anotada. El script
compara el checkout con ese commit antes de compilar; un cambio de etiqueta
detiene el proceso. También admite únicamente el cambio local esperado en
`llvm/cmake/modules/AddLLVM.cmake`, necesario para el enlazador de iOS.

Para reproducir la consulta sin ejecutar el código descargado:

```sh
git ls-remote https://github.com/llvm/llvm-project.git 'refs/tags/llvmorg-15.0.7*'
```

Esta comprobación fija la identidad de la fuente obtenida por Git. No sustituye
una verificación de la firma GPG de la etiqueta ni una auditoría de LLVM y sus
dependencias de compilación. Los archivos LLVM restaurados desde una caché de
Actions aún requieren confiar en el productor de esa caché.
