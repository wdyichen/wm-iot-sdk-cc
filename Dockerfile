# WM IoT SDK 命令行编译环境（多阶段构建）
# 参考: https://doc.winnermicro.net/w800/zh_CN/latest/get_started/linux.html
#
# 构建前请将依赖包放入 packages/ 目录，详见 packages/README.md

# ---------------------------------------------------------------------------
# Stage 1: 解压/安装 packages/ 中的全部工具（不进入最终镜像）
# ---------------------------------------------------------------------------
FROM ubuntu:20.04 AS packages

ARG DEBIAN_FRONTEND=noninteractive

ENV WM_TOOLS_ROOT=/opt/wm/tools
ENV WM_TOOLCHAIN_ROOT=${WM_TOOLS_ROOT}/toolchain
ENV WM_DEBUGSERVER_ROOT=${WM_TOOLS_ROOT}/debugserver

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    findutils \
    tar \
    gzip \
    xz-utils \
    unzip \
    file \
    grep \
    && rm -rf /var/lib/apt/lists/*

COPY packages/ /tmp/wm-packages/
COPY scripts/install-toolchain.sh \
     scripts/install-debugserver.sh \
     scripts/install-buildtools.sh \
     /tmp/wm-install/

RUN sed -i 's/\r$//' /tmp/wm-install/*.sh \
    && chmod +x /tmp/wm-install/*.sh \
    && STRIP_TOOLCHAIN_DOCS=1 \
       /tmp/wm-install/install-buildtools.sh /tmp/wm-packages ${WM_TOOLS_ROOT} \
    && STRIP_TOOLCHAIN_DOCS=1 \
       /tmp/wm-install/install-toolchain.sh /tmp/wm-packages ${WM_TOOLCHAIN_ROOT} \
    && /tmp/wm-install/install-debugserver.sh /tmp/wm-packages ${WM_DEBUGSERVER_ROOT} \
    && rm -rf /tmp/wm-packages /tmp/wm-install

# ---------------------------------------------------------------------------
# Stage 2: 最终运行镜像
# ---------------------------------------------------------------------------
FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive
ARG WM_USER=user
ARG WM_UID=1000
ARG WM_GID=1000

ENV WM_TOOLS_ROOT=/opt/wm/tools
ENV WM_TOOLCHAIN_ROOT=${WM_TOOLS_ROOT}/toolchain
ENV WM_DEBUGSERVER_ROOT=${WM_TOOLS_ROOT}/debugserver
ENV WM_IOT_SDK_PATH=/workspace/wm_iot_sdk
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

LABEL maintainer="WinnerMicro WM IoT SDK"
LABEL description="WM IoT SDK command-line compilation environment (Linux)"
LABEL reference="https://doc.winnermicro.net/w800/zh_CN/latest/get_started/linux.html"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-tk \
    git \
    wget \
    libncurses5 \
    libtinfo5 \
    libusb-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

# CMake / Ninja / Ccache / 工具链 / DebugServer（均来自 packages/）
COPY --from=packages /opt/wm/tools /opt/wm/tools

# Python 依赖（编译 + 文档）
COPY requirements-cc.txt requirements-doc.txt /opt/wm/python-reqs/
RUN python3 -m pip install --no-cache-dir \
    -r /opt/wm/python-reqs/requirements-cc.txt \
    -r /opt/wm/python-reqs/requirements-doc.txt \
    && rm -rf /root/.cache

# 用户与入口
RUN groupadd -g ${WM_GID} ${WM_USER} \
    && useradd -m -u ${WM_UID} -g ${WM_GID} -s /bin/bash ${WM_USER}

COPY udev/99-csky-cklink.rules /etc/udev/rules.d/99-csky-cklink.rules
COPY env/wm-env.sh /etc/profile.d/wm-env.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /etc/profile.d/wm-env.sh /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && echo 'source /etc/profile.d/wm-env.sh' >> /home/${WM_USER}/.bashrc \
    && mkdir -p /home/${WM_USER}/.ccache \
    && chown -R ${WM_USER}:${WM_USER} /home/${WM_USER} /opt/wm

WORKDIR /workspace
USER ${WM_USER}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
