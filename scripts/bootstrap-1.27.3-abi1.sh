#!/bin/bash
# Bootstrap Go 1.27.3 for LoongArch ABI 1.0 (Kylin / UOS / Loongnix).
#
# Why: go.dev linux-loong64 is ABI 2.0 (ld-linux-loongarch-lp64d.so.1) and
# segfaults on Kylin ABI 1.0 (ld.so.1, ELF Flags=0x3, _NSIG=65).
#
# How: copy Loongnix go1.27.1 ABI1 (compiler + src), overlay upstream 1.27.3
# VERSION + crypto/x509 only, keep Loongnix runtime, then make.bash with
# GOROOT_BOOTSTRAP=that 1.27.1.
#
# Must run ON an ABI1 loong64 host. CGO_ENABLED=0.
set -euo pipefail

LOONGNIX_URL=${LOONGNIX_URL:-https://ftp.loongnix.cn/toolchain/golang/go-1.27/abi1.0/go1.27.1.linux-loong64.tar.gz}
UPSTREAM_SRC_URL=${UPSTREAM_SRC_URL:-https://dl.google.com/go/go1.27.3.src.tar.gz}
WORKDIR=${WORKDIR:-$PWD/build}
PREFIX=${PREFIX:-$WORKDIR/go-1.27.3-abi1}
BOOTSTRAP=${BOOTSTRAP:-$WORKDIR/go-loongnix-1.27.1/go}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}

need() { command -v "$1" >/dev/null || { echo "need $1" >&2; exit 1; }; }
need curl
need tar
need make

mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [[ ! -x $BOOTSTRAP/bin/go ]]; then
  echo "fetch Loongnix go1.27.1 ABI1"
  curl -fL --retry 3 -o go1.27.1.linux-loong64.tar.gz "$LOONGNIX_URL"
  mkdir -p "$(dirname "$BOOTSTRAP")"
  tar -C "$(dirname "$BOOTSTRAP")" -xzf go1.27.1.linux-loong64.tar.gz
  # tarball extracts to ./go
  if [[ ! -d $BOOTSTRAP && -d $(dirname "$BOOTSTRAP")/go ]]; then
    BOOTSTRAP="$(dirname "$BOOTSTRAP")/go"
  fi
fi
"$BOOTSTRAP/bin/go" version

if [[ ! -f $WORKDIR/go1.27.3.src/src/crypto/x509/x509.go ]]; then
  echo "fetch upstream go1.27.3 src"
  curl -fL --retry 3 -o go1.27.3.src.tar.gz "$UPSTREAM_SRC_URL"
  mkdir -p go1.27.3.src
  tar -C go1.27.3.src --strip-components=1 -xzf go1.27.3.src.tar.gz
fi

echo "copy Loongnix tree -> $PREFIX"
rm -rf "$PREFIX"
mkdir -p "$(dirname "$PREFIX")"
cp -a "$BOOTSTRAP" "$PREFIX"

echo "overlay upstream VERSION + crypto/x509 (keep Loongnix runtime)"
cp -a "$WORKDIR/go1.27.3.src/VERSION" "$PREFIX/VERSION"
rm -rf "$PREFIX/src/crypto/x509"
cp -a "$WORKDIR/go1.27.3.src/src/crypto/x509" "$PREFIX/src/crypto/x509"

if ! grep -q '_NSIG.*=.*65' "$PREFIX/src/runtime/os_linux_loong64.go"; then
  echo "runtime _NSIG is not 65; refusing to build (would not be ABI1)" >&2
  grep _NSIG "$PREFIX/src/runtime/os_linux_loong64.go" >&2 || true
  exit 1
fi
echo "VERSION=$(head -1 "$PREFIX/VERSION")"
echo "_NSIG=$(grep _NSIG "$PREFIX/src/runtime/os_linux_loong64.go")"

export GOROOT_BOOTSTRAP=$BOOTSTRAP
unset GOROOT || true
export GOTOOLCHAIN=local
export CGO_ENABLED=0
export GOMAXPROCS=$JOBS
unset GOOS GOARCH GOHOSTOS GOHOSTARCH || true

cd "$PREFIX/src"
echo "make.bash start $(date -Iseconds)"
./make.bash
echo "make.bash end $(date -Iseconds)"

"$PREFIX/bin/go" version
file "$PREFIX/bin/go" || true
readelf -h "$PREFIX/bin/go" | grep -E 'Flags|Machine' || true

echo "OK $PREFIX"
echo "pack: tar --exclude=pkg/obj --exclude=pkg/bootstrap -C $(dirname "$PREFIX") -czf go1.27.3.linux-loong64-abi1.tar.gz $(basename "$PREFIX")"
echo "then rename inner dir to go/ if you want the official layout (extracts to ./go)"
