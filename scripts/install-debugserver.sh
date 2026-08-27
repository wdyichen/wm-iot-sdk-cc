#!/usr/bin/env bash
# 安装 XuanTie DebugServer（从 .sh.tar.gz 自解压包中提取）
set -euo pipefail

PACKAGES_DIR="${1:?packages directory required}"
INSTALL_DIR="${2:?install directory required}"

DEBUGSERVER_ARCHIVE="XuanTie-DebugServer-linux-x86_64-V5.18.1-20240513.sh.tar.gz"
ARCHIVE_PATH="${PACKAGES_DIR}/${DEBUGSERVER_ARCHIVE}"

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
    echo "ERROR: DebugServer archive not found: ${ARCHIVE_PATH}" >&2
    echo "Please download ${DEBUGSERVER_ARCHIVE} from:" >&2
    echo "  https://www.xrvm.cn/community/download" >&2
    echo "and place it in the packages/ directory before building." >&2
    exit 1
fi

mkdir -p "${INSTALL_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

# 查找 .sh 安装脚本
SH_FILE="$(find "${TMP_DIR}" -maxdepth 1 -type f -name '*.sh' | head -1)"
if [[ -z "${SH_FILE}" ]]; then
    echo "ERROR: Cannot find .sh installer inside ${DEBUGSERVER_ARCHIVE}" >&2
    exit 1
fi

chmod +x "${SH_FILE}"

# 从自解压脚本中提取内嵌 tar.gz（跳过 shell 脚本头部）
SKIP_LINE="$(awk '/^exit 0$/{print NR+1; exit}' "${SH_FILE}")"
if [[ -z "${SKIP_LINE}" ]]; then
    # 备用：搜索 gzip 魔数所在行
    SKIP_LINE="$(grep -abo $'\x1f\x8b\x08' "${SH_FILE}" | head -1 | cut -d: -f1)"
    if [[ -n "${SKIP_LINE}" ]]; then
        SKIP_LINE="$(head -c "${SKIP_LINE}" "${SH_FILE}" | wc -l)"
        SKIP_LINE=$((SKIP_LINE + 1))
    else
        echo "ERROR: Cannot determine embedded archive offset in ${SH_FILE}" >&2
        exit 1
    fi
fi

tail -n +"${SKIP_LINE}" "${SH_FILE}" | tar -xzf - -C "${INSTALL_DIR}"

# 兼容不同版本的目录结构
if [[ -d "${INSTALL_DIR}/XUANTIE_DebugServer" ]]; then
    shopt -s dotglob
    mv "${INSTALL_DIR}/XUANTIE_DebugServer"/* "${INSTALL_DIR}/"
    rmdir "${INSTALL_DIR}/XUANTIE_DebugServer"
    shopt -u dotglob
elif [[ -d "${INSTALL_DIR}/T-Head_DebugServer" ]]; then
    shopt -s dotglob
    mv "${INSTALL_DIR}/T-Head_DebugServer"/* "${INSTALL_DIR}/"
    rmdir "${INSTALL_DIR}/T-Head_DebugServer"
    shopt -u dotglob
fi

if [[ ! -f "${INSTALL_DIR}/DebugServerConsole.elf" ]]; then
    # 可能在 bin 子目录
    BIN_ELF="$(find "${INSTALL_DIR}" -name 'DebugServerConsole.elf' -print -quit)"
    if [[ -n "${BIN_ELF}" ]]; then
        BIN_DIR="$(dirname "${BIN_ELF}")"
        if [[ "${BIN_DIR}" != "${INSTALL_DIR}" ]]; then
            shopt -s dotglob
            mv "${BIN_DIR}"/* "${INSTALL_DIR}/"
            shopt -u dotglob
        fi
    fi
fi

if [[ ! -f "${INSTALL_DIR}/DebugServerConsole.elf" ]]; then
    echo "ERROR: DebugServer installation failed, DebugServerConsole.elf not found." >&2
    exit 1
fi

chmod +x "${INSTALL_DIR}/DebugServerConsole.elf"

# 删除示例与文档（不影响调试功能）
for relpath in example examples doc docs; do
    rm -rf "${INSTALL_DIR}/${relpath}" 2>/dev/null || true
done
find "${INSTALL_DIR}" -type f \( -name '*.pdf' -o -name '*.chm' \) -delete 2>/dev/null || true

echo "DebugServer installed to ${INSTALL_DIR}"
