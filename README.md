# LoongArch ABI 1.0 Go toolchains

公开的 **ABI 1.0** Go 工具链，给麒麟 / 统信 UOS / Loongnix 用（`ld.so.1`，ELF Flags=`0x3`）。

**不是** [go.dev](https://go.dev/dl/) 的 `linux-loong64`（那是 ABI 2.0，麒麟 ABI1 上会 segfault）。

当前 Release：[go1.27.3-linux-loong64-abi1](https://github.com/yibaiba/go-loong64-abi1/releases/tag/go1.27.3-linux-loong64-abi1)

## 用编译好的包

```bash
curl -fL -O https://github.com/yibaiba/go-loong64-abi1/releases/download/go1.27.3-linux-loong64-abi1/go1.27.3.linux-loong64-abi1.tar.gz
tar -C /usr/local -xzf go1.27.3.linux-loong64-abi1.tar.gz
export GOROOT=/usr/local/go
export PATH=$GOROOT/bin:$PATH
export GOTOOLCHAIN=local
export CGO_ENABLED=0
go version   # go1.27.3 linux/loong64
```

## 怎么编出来的（以后要改走这里）

必须在 **ABI1 龙芯机** 上编（麒麟 V10 loongarch64 等）。不能在 amd64 上交叉出 ABI1 的 `go` 二进制。

思路：Loongnix 已经有能跑的 ABI1 **go1.27.1**（带完整 src）。用它当 `GOROOT_BOOTSTRAP`，把官方 1.27.3 的 `VERSION` 和 `crypto/x509` 叠上去，**runtime 仍用 Loongnix 的**（`_NSIG=65`），再 `./make.bash`。这样 `go version` 是 1.27.3，ELF 仍是 ABI1。

不要整棵换成官方 1.27.3 src：官方 loong64 runtime 是 ABI2。

```bash
# 在龙芯 ABI1 上
git clone https://github.com/yibaiba/go-loong64-abi1.git
cd go-loong64-abi1
bash scripts/bootstrap-1.27.3-abi1.sh
# 产物默认在 ./build/go-1.27.3-abi1
bash scripts/pack-release.sh ./build/go-1.27.3-abi1
```

Loongnix 源（本机访问不了就先下好放到 `WORKDIR`）：

- https://ftp.loongnix.cn/toolchain/golang/go-1.27/abi1.0/go1.27.1.linux-loong64.tar.gz

官方 src：

- https://dl.google.com/go/go1.27.3.src.tar.gz

只叠这两处，其余保持 Loongnix 1.27.1：

| 叠上去 | 保持不动 |
| --- | --- |
| `VERSION`（写成 go1.27.3） | `src/runtime/os_linux_loong64.go`（`_NSIG = 65`） |
| `src/crypto/x509` | 链接器、syscall、cgo 相关 ABI |

编完检查：

```bash
go version                          # go1.27.3 linux/loong64
readelf -h bin/go | grep Flags      # 0x3
grep _NSIG src/runtime/os_linux_loong64.go
```

`make.bash` 环境：`GOROOT_BOOTSTRAP=<loongnix-1.27.1> GOTOOLCHAIN=local CGO_ENABLED=0`。

以后若要跟更高官方小版本：同样只叠 `VERSION` + 需要的 std 包，先确认 runtime 仍是 `_NSIG=65` / Flags=`0x3`，再打包上传 Release。
