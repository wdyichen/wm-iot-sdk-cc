#!/usr/bin/env bash
# 构建 WM IoT SDK Docker 编译环境
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

REQUIRED_PACKAGES=(
    "csky-elfabiv2-tools-x86_64-minilibc-20210423.tar.gz"
    "XuanTie-DebugServer-linux-x86_64-V5.18.1-20240513.sh.tar.gz"
    "cmake-3.25.1-linux-x86_64.sh"
    "ninja-linux.zip"
    "ccache-4.7.4-linux-x86_64.tar.xz"
)

missing=0
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if [[ ! -f "packages/${pkg}" ]]; then
        echo "ERROR: Missing packages/${pkg}" >&2
        missing=1
    fi
done

if [[ "${missing}" -eq 1 ]]; then
    echo "" >&2
    echo "请将所有依赖包放入 packages/ 目录，详见 packages/README.md" >&2
    exit 1
fi

IMAGE_NAME="${IMAGE_NAME:-wm-iot-sdk-cc:latest}"
WM_UID="${WM_UID:-$(id -u)}"
WM_GID="${WM_GID:-$(id -g)}"

echo "Building ${IMAGE_NAME} (UID=${WM_UID}, GID=${WM_GID})..."
docker build \
    --build-arg WM_UID="${WM_UID}" \
    --build-arg WM_GID="${WM_GID}" \
    -t "${IMAGE_NAME}" \
    .

echo ""
echo "Build complete: ${IMAGE_NAME}"
echo ""
echo "Quick start:"
echo "  docker compose run --rm wm-iot-sdk-cc"
echo ""
echo "Inside container, verify environment:"
echo "  cmake --version"
echo "  ninja --version"
echo "  ccache --version"
echo "  csky-elfabiv2-gcc --version"
echo "  wm.py --help"
