#!/usr/bin/env bash
# 从 packages/ 安装 CMake、Ninja、Ccache 预编译包
set -euo pipefail

PACKAGES_DIR="${1:?packages directory required}"
TOOLS_ROOT="${2:?tools root required}"

CMAKE_SH="cmake-3.25.1-linux-x86_64.sh"
NINJA_ZIP="ninja-linux.zip"
CCACHE_ARCHIVE="ccache-4.7.4-linux-x86_64.tar.xz"

CMAKE_INSTALL="${TOOLS_ROOT}/cmake"
NINJA_INSTALL="${TOOLS_ROOT}/ninja"
CCACHE_INSTALL="${TOOLS_ROOT}/ccache"

for f in "${CMAKE_SH}" "${NINJA_ZIP}" "${CCACHE_ARCHIVE}"; do
    if [[ ! -f "${PACKAGES_DIR}/${f}" ]]; then
        echo "ERROR: Missing ${PACKAGES_DIR}/${f}" >&2
        exit 1
    fi
done

mkdir -p "${CMAKE_INSTALL}" "${NINJA_INSTALL}" "${CCACHE_INSTALL}/bin"

# CMake（自解压安装脚本）
CMAKE_PATH="${PACKAGES_DIR}/${CMAKE_SH}"
chmod +x "${CMAKE_PATH}"
"${CMAKE_PATH}" --skip-license --prefix="${CMAKE_INSTALL}" --exclude-subdir

if [[ ! -x "${CMAKE_INSTALL}/bin/cmake" ]]; then
    echo "ERROR: cmake not found after installing ${CMAKE_SH}" >&2
    exit 1
fi

# Ninja（zip 内为单个 ninja 可执行文件）
unzip -q -o "${PACKAGES_DIR}/${NINJA_ZIP}" -d "${NINJA_INSTALL}"
chmod +x "${NINJA_INSTALL}/ninja"

# Ccache（仅保留二进制，丢弃文档）
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
tar -xJf "${PACKAGES_DIR}/${CCACHE_ARCHIVE}" -C "${TMP_DIR}"
CCACHE_BIN="$(find "${TMP_DIR}" -type f -name 'ccache' | head -1)"
if [[ -z "${CCACHE_BIN}" || ! -f "${CCACHE_BIN}" ]]; then
    echo "ERROR: ccache binary not found in ${CCACHE_ARCHIVE}" >&2
    exit 1
fi
install -m 0755 "${CCACHE_BIN}" "${CCACHE_INSTALL}/bin/ccache"

# 删除文档以减小体积
if [[ "${STRIP_TOOLCHAIN_DOCS:-0}" == "1" ]]; then
    for relpath in share/doc share/man share/info; do
        rm -rf "${CMAKE_INSTALL}/${relpath}" 2>/dev/null || true
    done
fi

echo "CMake installed: $("${CMAKE_INSTALL}/bin/cmake" --version | head -1)"
echo "Ninja installed: $("${NINJA_INSTALL}/ninja" --version)"
echo "Ccache installed: $("${CCACHE_INSTALL}/bin/ccache" --version | head -1)"
