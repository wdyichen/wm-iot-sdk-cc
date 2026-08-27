#!/usr/bin/env bash
# 安装 CSKY 工具链
set -euo pipefail

PACKAGES_DIR="${1:?packages directory required}"
INSTALL_DIR="${2:?install directory required}"

TOOLCHAIN_ARCHIVE="csky-elfabiv2-tools-x86_64-minilibc-20210423.tar.gz"
ARCHIVE_PATH="${PACKAGES_DIR}/${TOOLCHAIN_ARCHIVE}"

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
    echo "ERROR: Toolchain archive not found: ${ARCHIVE_PATH}" >&2
    echo "Please place ${TOOLCHAIN_ARCHIVE} in the packages/ directory before building." >&2
    exit 1
fi

mkdir -p "${INSTALL_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

# 查找 csky 交叉编译器（兼容不同命名）
GCC_BIN="$(find "${TMP_DIR}" -type f \( -name 'csky-elfabiv2-gcc' -o -name 'csky-abiv2-elf-gcc' \) | head -1)"
if [[ -z "${GCC_BIN}" ]]; then
    echo "ERROR: csky-elfabiv2-gcc not found in ${TOOLCHAIN_ARCHIVE}" >&2
    exit 1
fi
TOOLCHAIN_SRC="$(dirname "$(dirname "${GCC_BIN}")")"
if [[ ! -d "${TOOLCHAIN_SRC}/bin" ]]; then
    echo "ERROR: Cannot locate toolchain bin directory in ${TOOLCHAIN_ARCHIVE}" >&2
    exit 1
fi

shopt -s dotglob
mv "${TOOLCHAIN_SRC}"/* "${INSTALL_DIR}/"
shopt -u dotglob

GCC_NAME="$(basename "${GCC_BIN}")"
if [[ ! -x "${INSTALL_DIR}/bin/${GCC_NAME}" ]]; then
    echo "ERROR: Toolchain installation failed, ${GCC_NAME} not found." >&2
    exit 1
fi

echo "Toolchain installed to ${INSTALL_DIR}"
"${INSTALL_DIR}/bin/${GCC_NAME}" --version | head -1

# 删除工具链文档/man 页面以减小镜像体积（不影响编译）
if [[ "${STRIP_TOOLCHAIN_DOCS:-0}" == "1" ]]; then
    for relpath in share/doc share/man share/info share/locale; do
        rm -rf "${INSTALL_DIR}/${relpath}" 2>/dev/null || true
    done
    find "${INSTALL_DIR}" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    echo "Stripped toolchain documentation (STRIP_TOOLCHAIN_DOCS=1)"
fi
