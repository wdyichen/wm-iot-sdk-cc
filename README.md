# WM IoT SDK Docker 命令行编译环境

基于 [WinnerMicro 官方 Linux 编译环境文档](https://doc.winnermicro.net/w800/zh_CN/latest/get_started/linux.html) 制作的 Docker 镜像，用于在 Linux 容器中编译 WM IoT SDK 工程。

## 环境内容

| 组件 | 版本 / 说明 |
|------|-------------|
| 基础系统 | Ubuntu 20.04 |
| CMake | 3.25.1（packages 预编译包） |
| Ninja | 1.11.x（packages 预编译包） |
| Ccache | 4.7.4（packages 预编译包） |
| Python | Python 3.8 + pip + Tkinter（python3-tk） |
| 工具链 | csky-elfabiv2-tools-x86_64-minilibc-20210423 |
| DebugServer | XuanTie-DebugServer-linux-x86_64-V5.18.1-20240513 |
| Python 依赖 | requirements-cc.txt + requirements-doc.txt |
| 其他 | git、wget、libncurses5、USB udev 规则（CK-Link 调试） |

镜像采用多阶段构建；CMake/Ninja/Ccache/工具链/DebugServer 均从 `packages/` 本地安装，构建过程无需联网下载。

## 快速开始

### 1. 构建镜像

```bash
docker build -t wm-iot-sdk-cc:latest .
```

或：

```bash
cd wm_iot_sdk_cc
chmod +x build.sh scripts/*.sh
./build.sh
```


注意：也可以不自己构建镜像，使用现成的镜像 `wdyichen/wm-iot-sdk-cc:latest`。

### 2. 运行容器

**方式 A：docker run**

```bash
docker run -it --rm \
  -v /path/to/wm_iot_sdk:/workspace/wm_iot_sdk \
  -v $(pwd)/workspace:/workspace/project \
  wm-iot-sdk-cc:latest
```

**方式 B：docker compose**

```bash
# 设置 WM IoT SDK 源码在主机上的路径
export WM_IOT_SDK_HOST_PATH=/path/to/wm_iot_sdk

docker compose run --rm wm-iot-sdk-cc
```

注意，如果在 `Windows` 下直接使用现成的镜像并以 `docker run` 运行则为
```bash
docker run -it --rm -v "D:\workdir\wm_iot_sdk:/workspace/wm_iot_sdk" -v "D:\workdir\pwm_led:/workspace/project" wdyichen/wm-iot-sdk-cc:latest
```

### 3. 验证环境

进入容器后执行：

```bash
# WM 构建工具
wm.py --help
```

### 4. 编译示例工程

```bash
cd /workspace/wm_iot_sdk/examples/helloworld
wm.py build
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `WM_IOT_SDK_PATH` | `/workspace/wm_iot_sdk` | WM IoT SDK 根目录 |
| `WM_TOOLCHAIN_ROOT` | `/opt/wm/tools/toolchain` | 工具链安装路径 |
| `WM_DEBUGSERVER_ROOT` | `/opt/wm/tools/debugserver` | DebugServer 安装路径 |
| `CCACHE_DIR` | `/home/user/.ccache` | Ccache 缓存目录 |

切换 SDK 版本时，只需修改 `WM_IOT_SDK_PATH` 并重新挂载对应目录即可，参考[官方文档](https://doc.winnermicro.net/w800/zh_CN/latest/get_started/linux.html)：

```bash
export WM_IOT_SDK_PATH=/workspace/wm_iot_sdk_new
export PATH=$WM_IOT_SDK_PATH/tools/wm:$PATH
```

## USB 设备透传（烧录 / 调试）

编译完成后，通常需要通过 USB 连接开发板进行**固件下载**（串口）或 **JTAG 调试**（CK-Link 等）。容器内已预装 DebugServer 及 CK-Link udev 规则，但 USB 设备本身在主机上，需将其透传给容器才能使用。

> **平台说明**
> - **Linux 原生 Docker**：支持最好，`--device` 直接映射设备节点，推荐用于烧录与调试（见下方「Linux / WSL2」章节）。
> - **WSL2 + Docker Desktop**：需先用 [usbipd-win](https://github.com/dorssel/usbipd-win) 将 USB 设备附加到 WSL2，之后**与 Linux 方式相同**（见「WSL2」章节）。
> - **macOS + Docker Desktop**：**与 Linux 方式不同**，不能直接使用 `--device /dev/ttyUSB0`（见「macOS」章节）。
> - **Windows 原生 Docker Desktop（非 WSL2）**：同样无法像 Linux 一样直接透传，建议用 WSL2 或 Linux 主机。

> **重要**：下文「方式一 / 方式二 / 方式三」均适用于 **Linux 主机**，或在 **WSL2 中已通过 usbipd 附加 USB 设备之后** 的环境。macOS 用户请先阅读 [macOS 下的 USB 透传](#macos-下的-usb-透传) 小节。

### 主机侧准备（Linux / WSL2）

1. **将当前用户加入 `dialout` / `plugdev` 组**（访问串口与 USB 设备）：

```bash
sudo usermod -aG dialout,plugdev $USER
# 重新登录后生效
```

2. **（可选）安装 CK-Link udev 规则**——若主机上也需直接使用 DebugServer，可将本仓库规则复制到系统：

```bash
sudo cp udev/99-csky-cklink.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

3. **插入设备后确认已被系统识别**：

```bash
# 查看 USB 设备（CK-Link 等）
lsusb

# 查看串口（USB 转串口，用于 wm.py 烧录）
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

常见设备示例：

| 用途 | 典型设备节点 | 说明 |
|------|-------------|------|
| 串口烧录 | `/dev/ttyUSB0`、`/dev/ttyACM0` | USB 转 UART 下载固件 |
| CK-Link 调试 | USB 总线（见 `lsusb`） | Vendor ID 常见 `32bf:b210` |

---

### 方式一：透传整个 USB 总线（Linux / WSL2，推荐）

适用于 CK-Link 调试、串口烧录等多种 USB 设备。`docker-compose.yml` 已默认配置：

```yaml
devices:
  - /dev/bus/usb:/dev/bus/usb
group_add:
  - plugdev
```

直接启动即可：

```bash
export WM_IOT_SDK_HOST_PATH=/path/to/wm_iot_sdk
docker compose run --rm wm-iot-sdk-cc
```

等价的 `docker run` 命令：

```bash
docker run -it --rm \
  --device /dev/bus/usb:/dev/bus/usb \
  --group-add plugdev \
  -v /path/to/wm_iot_sdk:/workspace/wm_iot_sdk \
  wm-iot-sdk-cc:latest
```

进入容器后验证 USB 是否可见：

```bash
lsusb
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

---

### 方式二：仅透传指定设备（Linux / WSL2，更安全）

若只想暴露某个串口或单个 USB 设备，使用 `--device` 逐一映射，避免将整个 USB 总线交给容器。

**串口烧录示例**（假设主机设备为 `/dev/ttyUSB0`）：

```bash
docker run -it --rm \
  --device /dev/ttyUSB0:/dev/ttyUSB0 \
  --group-add dialout \
  -v /path/to/wm_iot_sdk:/workspace/wm_iot_sdk \
  wm-iot-sdk-cc:latest
```

**多个设备**：

```bash
docker run -it --rm \
  --device /dev/ttyUSB0:/dev/ttyUSB0 \
  --device /dev/ttyACM0:/dev/ttyACM0 \
  --group-add dialout \
  --group-add plugdev \
  -v /path/to/wm_iot_sdk:/workspace/wm_iot_sdk \
  wm-iot-sdk-cc:latest
```

在容器内使用 WM IoT SDK 烧录（端口名与主机一致）：

```bash
cd /workspace/wm_iot_sdk/examples/helloworld
wm.py build
wm.py flash -p /dev/ttyUSB0
```

> 具体烧录命令以 SDK 文档及 `wm.py flash --help` 为准。

---

### 方式三：JTAG 调试（Linux / WSL2，CK-Link + DebugServer）

1. 用**方式一**启动容器，确保 `lsusb` 能看到 CK-Link（如 `32bf:b210`）。
2. 在容器内启动 DebugServer：

```bash
DebugServerConsole.elf
```

3. 另开终端进入同一容器（或同镜像新容器，同样需 USB 透传），使用工具链 GDB 连接：

```bash
csky-elfabiv2-gdb build/your_app.elf
(gdb) target remote localhost:1025
(gdb) hb xxx_func
(gdb) continue
```

若 DebugServer 提示找不到设备，检查：
- 容器是否已映射 `/dev/bus/usb`
- 主机 `lsusb` 是否能看到 CK-Link
- 是否需重新插拔调试器

---

### WSL2 下的 USB 透传（Windows 用户）

Windows 上可通过 **usbipd-win** 将 USB 设备附加到 WSL2，再在 WSL2 内运行 Docker 容器。

1. 在 **Windows（管理员 PowerShell）** 安装并绑定设备：

```powershell
# 安装 usbipd-win（需已安装 winget）
winget install dorssel.usbipd-win

# 查看 USB 设备列表
usbipd list

# 将设备绑定到 WSL（BUSID 替换为实际值，如 1-4）
usbipd bind --busid 1-4
```

2. 在 **WSL2** 中附加设备：

```bash
# Windows 侧执行（或在 WSL 中调用 usbipd.exe）
usbipd attach --wsl --busid 1-4
```

3. 在 WSL2 中确认设备出现后，按 Linux 方式启动容器：

```bash
lsusb
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

export WM_IOT_SDK_HOST_PATH=/path/to/wm_iot_sdk
docker compose run --rm wm-iot-sdk-cc
```

4. 使用完毕后，在 Windows 侧解除附加：

```powershell
usbipd detach --busid 1-4
```

> WSL2 中 Docker 需使用 Docker Engine（非 Docker Desktop 的 Windows 容器模式），并确保 `/dev/bus/usb` 在 WSL 内存在。附加成功后，后续操作与 Linux 完全相同。

---

### macOS 下的 USB 透传

**macOS 与 Linux 方式不一样，不能照搬 `--device /dev/ttyUSB0` 或 `--device /dev/bus/usb`。**

| 对比项 | Linux / WSL2 | macOS |
|--------|--------------|-------|
| Docker 架构 | 原生或 WSL2 内核 | 容器运行在 Docker Desktop 的 Linux 虚拟机内 |
| 主机设备节点 | `/dev/ttyUSB0`、`/dev/ttyACM0`、`/dev/bus/usb` | `/dev/cu.usbserial-*`、`/dev/tty.usbmodem*` 等，**无** `ttyUSB` |
| `--device` 直接映射 | 支持 | **不支持**（主机设备节点无法直接映射进容器） |
| 推荐方案 | 方式一 / 方式二 | 见下方三种可选方案 |

#### 方案 A：容器编译 + 主机烧录（最稳妥，推荐）

在 macOS 上用 Docker **只做编译**，固件下载 / 调试在 **macOS 本机** 完成：

```bash
# 1. 容器内编译
docker compose run --rm wm-iot-sdk-cc
cd /workspace/wm_iot_sdk/examples/helloworld
wm.py build

# 2. 编译产物已通过 volume 挂载到主机，在 macOS 终端烧录
#    先查看串口名称（macOS 命名与 Linux 不同）
ls /dev/cu.usb*
# 常见：/dev/cu.usbserial-1410、/dev/cu.usbmodem*

# 3. 在 macOS 本机安装 Python 依赖后执行 wm.py flash
#    （或使用 WM Dev Suite / 其他 macOS 支持的烧录工具）
```

此方案不依赖 USB 透传，适合日常开发。

#### 方案 B：Docker Desktop USB/IP（实验性）

Docker Desktop 4.35+ 支持通过 [USB/IP 协议](https://docs.docker.com/desktop/features/usbip/) 将 USB 设备共享给容器，但：

- 需要在 **macOS 主机上运行 USB/IP Server**（生态不如 Windows 的 usbipd-win 成熟，串口类设备支持可能不完整）
- 需额外启动 **privileged 守护容器** 维持 USB 连接，步骤较繁琐
- 对 CK-Link、串口转 USB 等设备**不保证可用**

大致流程（参考 [Docker 官方文档](https://docs.docker.com/desktop/features/usbip/)）：

```bash
# 1. macOS 主机：运行 USB/IP Server，将本地 USB 设备导出
#    （需自行选用支持 macOS 的 USB/IP Server 实现）

# 2. 启动 privileged 容器并 attach 设备
docker run --rm -it --privileged --pid=host alpine
# 容器内：
nsenter -t 1 -m
usbip list -r host.docker.internal
usbip attach -r host.docker.internal -d <BUSID>

# 3. 另开 wm-iot-sdk-cc 容器，映射 attach 后出现的 /dev/ 节点
docker run -it --rm --device /dev/ttyUSB0 ... wm-iot-sdk-cc:latest
```

> 若 USB/IP 方案无法识别你的调试器或串口，请改用方案 A 或方案 C。

#### 方案 C：使用 Linux 环境（与 Linux 方式相同）

在 macOS 上如需完整的容器内烧录 / 调试体验，可改用：

- 带 USB 透传的 **Linux 实体机** 或 **Linux 虚拟机**（UTM / Parallels 等将 USB 设备分配给 Linux 客户机）
- 在 Linux 客户机内安装 Docker 后，按本文 **「方式一 / 方式二」** 操作，与原生 Linux **完全一致**

---

### 常见问题

| 现象 | 可能原因 | 处理建议 |
|------|----------|----------|
| 容器内 `lsusb` 为空 | 未映射 USB 总线 | 添加 `--device /dev/bus/usb:/dev/bus/usb`（仅 Linux / WSL2） |
| 无 `/dev/ttyUSB0` | 仅映射了 USB 总线但缺串口驱动节点 | 优先用方式一；或显式 `--device /dev/ttyUSB0` |
| macOS 上 `--device` 无效 | Docker Desktop 无法直接映射 macOS 设备 | 改用 [macOS 方案 A/B/C](#macos-下的-usb-透传) |
| Permission denied | 用户无设备访问权限 | 主机执行 `usermod -aG dialout,plugdev` 并重新登录（Linux） |
| DebugServer 找不到 ICE | CK-Link 未透传或驱动异常 | 检查 `lsusb`；重新 `usbipd attach`（WSL2） |
| 设备被主机占用 | 主机上已有串口工具打开 | 关闭 minicom、Serial 等后重试 |

若以上方式仍无法访问设备，可临时使用 `--privileged` 进行排查（**不建议长期使用**）：

```bash
docker run -it --rm --privileged \
  -v /path/to/wm_iot_sdk:/workspace/wm_iot_sdk \
  wm-iot-sdk-cc:latest
```

## 注意事项

1. **解压权限**：WM IoT SDK 中的脚本需要可执行权限。请在 Linux 中解压 SDK 压缩包，不要从 Windows 直接拷贝已解压的文件，否则会丢失权限信息。
2. **用户 UID**：`build.sh` 默认使用当前用户的 UID/GID 构建镜像，避免挂载目录权限问题。

## 参考链接

- [Linux 搭建命令行编译环境](https://doc.winnermicro.net/w800/zh_CN/latest/get_started/linux.html)
- [WM IoT SDK GitHub](https://github.com/winnermicro/wm_iot_sdk)
- [玄铁资源中心](https://www.xrvm.cn/community/download)
