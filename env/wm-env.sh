# WM IoT SDK 编译环境变量
# 参考: https://doc.winnermicro.net/w800/zh_CN/latest/get_started/linux.html

export WM_TOOLS_ROOT="${WM_TOOLS_ROOT:-/opt/wm/tools}"
export WM_TOOLCHAIN_ROOT="${WM_TOOLCHAIN_ROOT:-${WM_TOOLS_ROOT}/toolchain}"
export WM_DEBUGSERVER_ROOT="${WM_DEBUGSERVER_ROOT:-${WM_TOOLS_ROOT}/debugserver}"
export WM_CMAKE_ROOT="${WM_CMAKE_ROOT:-${WM_TOOLS_ROOT}/cmake}"
export WM_NINJA_ROOT="${WM_NINJA_ROOT:-${WM_TOOLS_ROOT}/ninja}"
export WM_CCACHE_ROOT="${WM_CCACHE_ROOT:-${WM_TOOLS_ROOT}/ccache}"

# CMake / Ninja / Ccache
export PATH="${WM_CMAKE_ROOT}/bin:${WM_NINJA_ROOT}:${WM_CCACHE_ROOT}/bin:${PATH}"

# 工具链
export PATH="${WM_TOOLCHAIN_ROOT}/bin:${PATH}"

# DebugServer
export PATH="${WM_DEBUGSERVER_ROOT}:${PATH}"
export LD_LIBRARY_PATH="${WM_DEBUGSERVER_ROOT}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# Ccache 缓存目录
export CCACHE_DIR="${CCACHE_DIR:-/home/user/.ccache}"

# WM IoT SDK 路径（运行时挂载后设置，或通过 docker-compose 环境变量指定）
export WM_IOT_SDK_PATH="${WM_IOT_SDK_PATH:-/workspace/wm_iot_sdk}"

if [[ -d "${WM_IOT_SDK_PATH}/tools/wm" ]]; then
    export PATH="${WM_IOT_SDK_PATH}/tools/wm:${PATH}"
fi
