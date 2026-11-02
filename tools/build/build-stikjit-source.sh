#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

[[ "$(uname -s)" == Darwin ]] || { echo "StikJIT must be built on macOS" >&2; exit 1; }
for program in git rustup xcrun xcodebuild curl unzip ditto shasum cmp; do
  command -v "$program" >/dev/null || { echo "Missing $program" >&2; exit 1; }
done

SOURCE="$ROOT/.jit-source"
[[ ! -e "$SOURCE/idevice" && ! -e "$SOURCE/StikJIT" ]] || {
  echo "Refusing to reuse an existing JIT source checkout" >&2
  exit 1
}
mkdir -p "$SOURCE"

# Verify the tool archive before extraction. Do not run its installer.
curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  'https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip' \
  --output "$SOURCE/xcodegen.zip"
echo '4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806  .jit-source/xcodegen.zip' \
  | shasum -a 256 --check
unzip -q "$SOURCE/xcodegen.zip" -d "$SOURCE"
XCODEGEN="$SOURCE/xcodegen/bin/xcodegen"
[[ -x "$XCODEGEN" ]] || { echo "XcodeGen binary missing" >&2; exit 1; }
[[ "$("$XCODEGEN" --version)" == *'2.46.0'* ]] || { echo "Wrong XcodeGen version" >&2; exit 1; }

git clone --depth 1 --branch v0.1.68 \
  https://github.com/jkcoxson/idevice.git "$SOURCE/idevice"
[[ "$(git -C "$SOURCE/idevice" rev-parse HEAD)" == d32c8189c51c2789496b0768039419c3705498c3 ]] || {
  echo "Unexpected idevice revision" >&2; exit 1;
}
git clone --depth 1 --branch 1.9.0 \
  https://github.com/StikDebug/StikJIT.git "$SOURCE/StikJIT"
[[ "$(git -C "$SOURCE/StikJIT" rev-parse HEAD)" == 32287268fa5824f9edce4cb359f5833ce0cf7b00 ]] || {
  echo "Unexpected StikJIT revision" >&2; exit 1;
}
[[ "$(shasum -a 256 "$SOURCE/StikJIT/idevice/libidevice_ffi.a" | cut -d' ' -f1)" == \
  4db23fe1d342927b9480bb9a8577f219994365621dc28aa0018e23ea1990ecc8 ]] || {
  echo "Unexpected vendored idevice archive" >&2; exit 1;
}

rustup toolchain install 1.99.0 --profile minimal --target aarch64-apple-ios
export SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
export IPHONEOS_DEPLOYMENT_TARGET=17.0
export CARGO_PROFILE_RELEASE_LTO=false
(
  cd "$SOURCE/idevice/ffi"
  cargo +1.99.0 build --locked --release --target aarch64-apple-ios \
    --no-default-features --features full,rustcrypto
)
FFI="$SOURCE/idevice/target/aarch64-apple-ios/release/libidevice_ffi.a"
[[ -s "$FFI" && -s "$SOURCE/idevice/ffi/idevice.h" ]] || {
  echo "idevice FFI output missing" >&2; exit 1;
}
shasum -a 256 "$FFI" "$SOURCE/idevice/ffi/idevice.h"
cp "$FFI" "$SOURCE/StikJIT/idevice/libidevice_ffi.a"
cp "$SOURCE/idevice/ffi/idevice.h" "$SOURCE/StikJIT/idevice/idevice.h"
[[ "$(shasum -a 256 "$SOURCE/StikJIT/idevice/libidevice_ffi.a" | cut -d' ' -f1)" != \
  4db23fe1d342927b9480bb9a8577f219994365621dc28aa0018e23ea1990ecc8 ]] || {
  echo "The prebuilt idevice archive was not replaced" >&2; exit 1;
}

(
  cd "$SOURCE/StikJIT"
  "$XCODEGEN" generate
  xcodebuild archive -scheme StikJIT -destination 'generic/platform=iOS' \
    -archivePath build/StikJIT BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO
  xcodebuild -create-xcframework \
    -framework build/StikJIT.xcarchive/Products/Library/Frameworks/StikJIT.framework \
    -output StikJIT.xcframework
)
FRAMEWORK="$SOURCE/StikJIT/StikJIT.xcframework"
[[ -s "$FRAMEWORK/ios-arm64/StikJIT.framework/StikJIT" ]] || {
  echo "Rebuilt StikJIT binary missing" >&2; exit 1;
}
shasum -a 256 "$FRAMEWORK/ios-arm64/StikJIT.framework/StikJIT"

VENDORED="$ROOT/app/Frameworks/StikJIT.xcframework"
[[ -d "$VENDORED" ]] || { echo "Bundled StikJIT input missing" >&2; exit 1; }
mv "$VENDORED" "$SOURCE/vendored-StikJIT.xcframework"
ditto "$FRAMEWORK" "$VENDORED"
cmp "$FRAMEWORK/ios-arm64/StikJIT.framework/StikJIT" \
  "$VENDORED/ios-arm64/StikJIT.framework/StikJIT"
