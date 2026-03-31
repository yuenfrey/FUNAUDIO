FROM nvidia/cuda:13.2.0-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VENV_PATH=/opt/venv \
    PYTHONPATH=/app \
    PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# APT 重试配置，减少偶发 502/超时
RUN printf 'Acquire::Retries "8";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80-retries

# Ubuntu 24.04 使用 DEB822 的 ubuntu.sources
# 这里把 archive / security 都替换到 USTC 中国镜像
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g; \
            s|http://security.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g; \
            s|https://archive.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g; \
            s|https://security.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
    /etc/apt/sources.list.d/ubuntu.sources

# 基础依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      git-lfs \
      ffmpeg \
      python3.12 \
      python3.12-venv \
      python3.12-dev \
      build-essential \
      g++ \
      make \
      cmake \
      pkg-config \
      libsndfile1 \
      libsndfile1-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 拉项目
RUN git clone --recurse-submodules https://github.com/FunAudioLLM/Fun-Audio-Chat.git .

# 提高 pyworld 在 Python 3.12 下的安装成功率
RUN sed -i 's/^pyworld==0.3.4$/pyworld==0.3.5/' requirements.txt || true

# Ubuntu 24.04 上不要直接往系统 Python 装包，使用 venv
RUN python3.12 -m venv ${VENV_PATH}
ENV PATH=${VENV_PATH}/bin:$PATH

# 先升级安装工具和基础编译依赖
RUN pip install --upgrade pip setuptools wheel && \
    pip install "numpy<2.0.0" cython

# 装 PyTorch 2.8.0 + cu128
RUN pip install torch==2.8.0 torchaudio==2.8.0 \
    --index-url https://download.pytorch.org/whl/cu128

# 装项目依赖
RUN pip install -r requirements.txt

# web demo/server 额外依赖
RUN pip install sphn aiohttp

# 不写死业务启动命令，交给 K8S YAML 传 command/args
CMD ["bash"]
