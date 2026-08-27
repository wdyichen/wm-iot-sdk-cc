#!/usr/bin/env bash
set -e

# 加载 WM 编译环境变量
# shellcheck source=/dev/null
source /etc/profile.d/wm-env.sh

# 若挂载了 WM IoT SDK，确保 wm.py 工具链脚本具有可执行权限
if [[ -d "${WM_IOT_SDK_PATH}/tools/wm" ]]; then
    find "${WM_IOT_SDK_PATH}/tools/wm" -type f \( -name '*.py' -o -name 'wm.py' \) -exec chmod +x {} + 2>/dev/null || true
    find "${WM_IOT_SDK_PATH}/tools/wm" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
fi

exec "$@"
