#!/bin/bash
# Pack PREFIX (a built GOROOT) as go1.27.3.linux-loong64-abi1.tar.gz
# extracting to ./go — same layout as the GitHub Release asset.
set -euo pipefail
PREFIX=${1:?usage: pack-release.sh /path/to/go-1.27.3-abi1}
OUT=${2:-$PWD/go1.27.3.linux-loong64-abi1.tar.gz}
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/go"
if command -v rsync >/dev/null; then
  rsync -a --exclude pkg/obj --exclude pkg/bootstrap "$PREFIX/" "$STAGE/go/"
else
  cp -a "$PREFIX"/. "$STAGE/go/"
  rm -rf "$STAGE/go/pkg/obj" "$STAGE/go/pkg/bootstrap"
fi
cat > "$STAGE/go/ABI1.txt" << 'NOTE'
This is NOT the official go.dev linux-loong64 toolchain (ABI 2.0).

It is Go 1.27.3 bootstrapped on LoongArch ABI 1.0 (Kylin/UOS/Loongnix)
from Loongnix go1.27.1 (GOROOT_BOOTSTRAP), with upstream 1.27.3 VERSION
and crypto/x509 overlaid. Runtime keeps _NSIG=65. ELF Flags=0x3 (OBJ-v0).

See scripts/bootstrap-1.27.3-abi1.sh in this repository to rebuild.

  tar -C /usr/local -xzf go1.27.3.linux-loong64-abi1.tar.gz
  export GOROOT=/usr/local/go PATH=$GOROOT/bin:$PATH GOTOOLCHAIN=local CGO_ENABLED=0
NOTE
tar -C "$STAGE" -czf "$OUT" go
ls -lh "$OUT"
sha256sum "$OUT"
