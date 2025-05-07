ARG BASE_IMAGE=debian
ARG BASE_IMAGE_TAG=12
ARG BUILD_ON_IMAGE=glcr.b-data.ch/python/ver
ARG MOJO_VERSION
ARG PYTHON_VERSION
ARG CUDA_IMAGE_FLAVOR

ARG NEOVIM_VERSION=0.11.1
ARG GIT_VERSION=2.49.0
ARG GIT_LFS_VERSION=3.6.1
ARG PANDOC_VERSION=3.6.3

ARG INSTALL_MAX
ARG BASE_SELECT=${INSTALL_MAX:+max}

FROM glcr.b-data.ch/neovim/nvsi:${NEOVIM_VERSION} AS nvsi
FROM glcr.b-data.ch/git/gsi/${GIT_VERSION}/${BASE_IMAGE}:${BASE_IMAGE_TAG} AS gsi
FROM glcr.b-data.ch/git-lfs/glfsi:${GIT_LFS_VERSION} AS glfsi

FROM ${BUILD_ON_IMAGE}${PYTHON_VERSION:+:}${PYTHON_VERSION}${CUDA_IMAGE_FLAVOR:+-}${CUDA_IMAGE_FLAVOR} AS files-cuda-max

ARG DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /files/opt/nvidia \
  && apt-get update \
  && apt-get -y install --no-install-recommends git \
  && git clone https://gitlab.com/nvidia/container-images/cuda.git \
  && cp -a cuda/entrypoint.d /files/opt/nvidia \
  && cp -a cuda/nvidia_entrypoint.sh /files/opt/nvidia

FROM ${BUILD_ON_IMAGE}${PYTHON_VERSION:+:}${PYTHON_VERSION}${CUDA_IMAGE_FLAVOR:+-}${CUDA_IMAGE_FLAVOR} AS base-cuda-max

## For use with the NVIDIA Container Runtime
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

## Add entrypoint items
COPY --from=files-cuda-max /files /
ENV NVIDIA_PRODUCT_NAME=CUDA
ENTRYPOINT ["/opt/nvidia/nvidia_entrypoint.sh"]

FROM ${BUILD_ON_IMAGE}${PYTHON_VERSION:+:}${PYTHON_VERSION}${CUDA_IMAGE_FLAVOR:+-}${CUDA_IMAGE_FLAVOR} AS base-max

## For use with the NVIDIA Container Runtime
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

FROM ${BUILD_ON_IMAGE}${PYTHON_VERSION:+:}${PYTHON_VERSION}${CUDA_IMAGE_FLAVOR:+-}${CUDA_IMAGE_FLAVOR} AS base-mojo

FROM base${CUDA_IMAGE_FLAVOR:+-cuda}-${BASE_SELECT:-mojo} AS base

ARG DEBIAN_FRONTEND=noninteractive

ARG BUILD_ON_IMAGE
ARG MOJO_VERSION
ARG CUDA_IMAGE_FLAVOR

ARG NEOVIM_VERSION
ARG GIT_VERSION
ARG GIT_LFS_VERSION
ARG PANDOC_VERSION

ARG CUDA_IMAGE_LICENSE=${CUDA_VERSION:+"NVIDIA Deep Learning Container License"}
ARG IMAGE_LICENSE=${CUDA_IMAGE_LICENSE:-"MAX Community License"}
ARG IMAGE_SOURCE=https://gitlab.b-data.ch/mojo/docker-stack
ARG IMAGE_VENDOR="b-data GmbH"
ARG IMAGE_AUTHORS="Olivier Benz <olivier.benz@b-data.ch>"

LABEL org.opencontainers.image.licenses="$IMAGE_LICENSE" \
      org.opencontainers.image.source="$IMAGE_SOURCE" \
      org.opencontainers.image.vendor="$IMAGE_VENDOR" \
      org.opencontainers.image.authors="$IMAGE_AUTHORS"

ENV PARENT_IMAGE=${BUILD_ON_IMAGE}${PYTHON_VERSION:+:}${PYTHON_VERSION}${CUDA_IMAGE_FLAVOR:+-}${CUDA_IMAGE_FLAVOR} \
    NEOVIM_VERSION=${NEOVIM_VERSION} \
    MODULAR_HOME=/opt/modular/share/max \
    MOJO_VERSION=${MOJO_VERSION%%-*} \
    GIT_VERSION=${GIT_VERSION} \
    GIT_LFS_VERSION=${GIT_LFS_VERSION} \
    PANDOC_VERSION=${PANDOC_VERSION}

## Install Neovim
COPY --from=nvsi /usr/local /usr/local
## Install Git
COPY --from=gsi /usr/local /usr/local
## Install Git LFS
COPY --from=glfsi /usr/local /usr/local

RUN dpkgArch="$(dpkg --print-architecture)" \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    bash-completion \
    build-essential \
    curl \
    file \
    fontconfig \
    g++ \
    gcc \
    gfortran \
    gnupg \
    htop \
    info \
    jq \
    libclang-dev \
    man-db \
    nano \
    ncdu \
    procps \
    psmisc \
    screen \
    sudo \
    swig \
    tmux \
    vim-tiny \
    wget \
    zsh \
    ## Neovim: Additional runtime recommendations
    ripgrep \
    ## Git: Additional runtime dependencies
    libcurl3-gnutls \
    liberror-perl \
    ## Git: Additional runtime recommendations
    less \
    ssh-client \
    ## Python: For h5py wheels (arm64)
    libhdf5-dev \
  ## Python: Additional dev dependencies
  && if [ -z "${PYTHON_VERSION}" ]; then \
    apt-get -y install --no-install-recommends \
      python3-dev \
      ## Install Python package installer
      ## (dep: python3-distutils, python3-setuptools and python3-wheel)
      python3-pip \
      ## Install venv module for python3
      python3-venv; \
    ## make some useful symlinks that are expected to exist
    ## ("/usr/bin/python" and friends)
    for src in pydoc3 python3 python3-config; do \
      dst="$(echo "$src" | tr -d 3)"; \
      if [ -s "/usr/bin/$src" ] && [ ! -e "/usr/bin/$dst" ]; then \
        ln -svT "$src" "/usr/bin/$dst"; \
      fi \
    done; \
  else \
    ## Force update pip, setuptools and wheel
    pip install --upgrade --force-reinstall \
      pip \
      setuptools \
      wheel; \
  fi \
  ## MAX/Mojo: Additional runtime dependency
  && apt-get -y install --no-install-recommends libncurses-dev \
  ## mblack: Additional Python dependencies
  && export PIP_BREAK_SYSTEM_PACKAGES=1 \
  && pip install \
    click \
    mypy-extensions \
    packaging \
    pathspec \
    platformdirs \
  ## Git: Set default branch name to main
  && git config --system init.defaultBranch main \
  ## Git: Store passwords for one hour in memory
  && git config --system credential.helper "cache --timeout=3600" \
  ## Git: Merge the default branch from the default remote when "git pull" is run
  && git config --system pull.rebase false \
  ## Install pandoc
  && curl -sLO https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-1-${dpkgArch}.deb \
  && dpkg -i pandoc-${PANDOC_VERSION}-1-${dpkgArch}.deb \
  && rm pandoc-${PANDOC_VERSION}-1-${dpkgArch}.deb \
  ## Clean up
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/* \
    ${HOME}/.cache

FROM base AS modular

ARG NB_GID=100

ARG MOJO_VERSION
ARG INSTALL_MAX

  ## Install Magic
RUN export MODULAR_HOME="$HOME/.modular" \
  && curl -ssL https://magic.modular.com | bash \
  && mv ${HOME}/.modular/bin/magic /usr/local/bin \
  ## Clean up
  && rm -rf ${HOME}/.modular \
  && rm -rf /usr/local/lib/python${PYTHON_VERSION%.*}/site-packages/*

  ## Install MAX/Mojo
RUN cd /tmp \
  && if [ "${INSTALL_MAX}" = "1" ] || [ "${INSTALL_MAX}" = "true" ]; then \
    if [ "${MOJO_VERSION}" = "nightly" ]; then \
      magic init -c conda-forge -c https://conda.modular.com/max-nightly; \
      magic add max max-pipelines; \
    else \
      magic init -c conda-forge -c https://conda.modular.com/max; \
      magic add max==${MOJO_VERSION} max-pipelines==${MOJO_VERSION}; \
    fi \
  else \
    if [ "${MOJO_VERSION}" = "nightly" ]; then \
      magic init -c conda-forge -c https://conda.modular.com/max-nightly; \
      magic add mojo-jupyter; \
    else \
      magic init -c conda-forge -c https://conda.modular.com/max; \
      magic add mojo-jupyter==${MOJO_VERSION}; \
    fi \
  fi \
  ## Disable telemetry
  && magic telemetry --manifest-path pixi.toml --disable \
  ## Get rid of all the unnecessary stuff
  ## and move installation to /opt/modular
  && mkdir -p /opt/modular/bin \
  && mkdir -p /opt/modular/lib \
  && mkdir -p /opt/modular/share \
  && cd /tmp/.magic/envs \
  && if [ "${INSTALL_MAX}" = "1" ] || [ "${INSTALL_MAX}" = "true" ]; then \
    cp -a default/bin/max* \
      /opt/modular/bin; \
    cp -a default/lib/libDevice* \
      default/lib/libGenericMLSupport* \
      default/lib/libmax.so \
      default/lib/libmodular* \
      default/lib/*MOGG* \
      default/lib/libmtorch.so \
      default/lib/libStock* \
      default/lib/libTorch* \
      /opt/modular/lib; \
    cp -a default/lib/python${PYTHON_VERSION%.*}/site-packages/max* \
      /usr/local/lib/python${PYTHON_VERSION%.*}/site-packages; \
  fi \
  && cp -a default/bin/lldb* \
    default/bin/mblack \
    default/bin/modular* \
    default/bin/mojo* \
    /opt/modular/bin \
  && cp -a default/lib/libAsyncRT* \
    default/lib/libATenRT.so \
    default/lib/libKGENCompilerRT* \
    default/lib/liblldb* \
    default/lib/libMGPRT.so \
    default/lib/libMojo* \
    default/lib/libMSupport* \
    default/lib/liborc_rt.a \
    default/lib/lldb* \
    default/lib/mojo* \
    /opt/modular/lib \
  && cp -a default/lib/python${PYTHON_VERSION%.*}/site-packages/*mblack* \
    default/lib/python${PYTHON_VERSION%.*}/site-packages/mblib* \
    /usr/local/lib/python${PYTHON_VERSION%.*}/site-packages \
  && cp -a default/share/max /opt/modular/share \
  && cp -a default/test /opt/modular \
  && mkdir ${MODULAR_HOME}/crashdb \
  && rm ${MODULAR_HOME}/firstActivation \
  ## Fix Modular home for Mojo
  && sed -i "s|/tmp/.magic/envs/default|/opt/modular|g" \
    ${MODULAR_HOME}/modular.cfg \
  && if [ "${INSTALL_MAX}" = "1" ] || [ "${INSTALL_MAX}" = "true" ]; then \
    ## Fix Python path for max-serve, max-pipelines
    sed -i "s|/tmp/.magic/envs/default|/usr/local|g" \
      /opt/modular/bin/max-serve \
      /opt/modular/bin/max-pipelines; \
  fi \
  ## Fix Python path for mblack
  && sed -i "s|/tmp/.magic/envs/default|/usr/local|g" \
    /opt/modular/bin/mblack \
  ## Fix permissions
  && chown -R root:${NB_GID} /opt/modular \
  && chmod -R g+w ${MODULAR_HOME}

## Install the Mojo kernel for Jupyter
RUN mkdir -p /usr/local/share/jupyter/kernels \
  && mv /tmp/.magic/envs/default/share/jupyter/kernels/mojo* \
    /usr/local/share/jupyter/kernels/ \
  ## Fix Modular home in the Mojo kernel for Jupyter
  && grep -rl /tmp/.magic/envs/default/share/jupyter /usr/local/share/jupyter/kernels/mojo* | \
    xargs sed -i "s|/tmp/.magic/envs/default|/usr/local|g" \
  && grep -rl /usr/local/share/max /usr/local/share/jupyter/kernels/mojo* | \
    xargs sed -i "s|/usr/local/share/max|/opt/modular/share/max|g" \
  ## Change display name in the Mojo kernel for Jupyter
  && sed -i "s|\"display_name\".*|\"display_name\": \"Mojo $MOJO_VERSION ${INSTALL_MAX:+(MAX)}\",|g" \
    /usr/local/share/jupyter/kernels/mojo*/kernel.json \
  && if [ "${MOJO_VERSION}" = "nightly" ]; then \
    cp -a /usr/local/share/jupyter/kernels/mojo*/nightly-logo-64x64.png \
      /usr/local/share/jupyter/kernels/mojo*/logo-64x64.png; \
    cp -a /usr/local/share/jupyter/kernels/mojo*/nightly-logo.svg \
      /usr/local/share/jupyter/kernels/mojo*/logo.svg; \
  fi

FROM base

ARG INSTALL_MAX

ENV PATH=/opt/modular/bin:$PATH
ENV MAGIC_NO_PATH_UPDATE=1

## Install MAX/Mojo
COPY --from=modular /opt /opt
## Install the Mojo kernel for Jupyter
COPY --from=modular /usr/local/share/jupyter /usr/local/share/jupyter
## Install Python packages to the site library
COPY --from=modular /usr/local/lib/python${PYTHON_VERSION%.*}/site-packages \
  /usr/local/lib/python${PYTHON_VERSION%.*}/site-packages

RUN echo MODULAR_HOME=\"\$HOME/.modular\" > /tmp/magicenv \
  && echo BIN_DIR=\"\$MODULAR_HOME/bin\" >> /tmp/magicenv \
  && cp /tmp/magicenv /var/tmp/magicenv.bak \
  && cp /tmp/magicenv /tmp/magicenv.mod \
  ## Create the user's modular bin dir
  && . /tmp/magicenv \
  && mkdir -p ${BIN_DIR} \
  && mkdir -p /etc/skel/.modular/bin \
  ## Append the user's modular bin dir to PATH
  && sed -i 's/\$HOME/\\$HOME/g' /tmp/magicenv.mod \
  && . /tmp/magicenv.mod \
  && echo "\n# Append the user's modular bin dir to PATH\nif [[ \"\$PATH\" != *\"${BIN_DIR}\"* ]] ; then\n    PATH=\"\$PATH:${BIN_DIR}\"\nfi" | tee -a ${HOME}/.bashrc \
    /etc/skel/.bashrc \
  ## Create the user's modular bin dir in the skeleton directory
  && HOME=/etc/skel . /tmp/magicenv \
  && mkdir -p ${BIN_DIR} \
  ## MAX/Mojo: Install Python dependencies
  && apt-get update \
  && apt-get -y install --no-install-recommends cmake \
  && export PIP_BREAK_SYSTEM_PACKAGES=1 \
  && if [ "${INSTALL_MAX}" = "1" ] || [ "${INSTALL_MAX}" = "true" ]; then \
    if [ -z "${CUDA_VERSION}" ]; then \
      ## MAX: Install CPU-only version of PyTorch in regular images
      export PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cpu"; \
    fi; \
    packages=$(grep "Requires-Dist:" \
      /usr/local/lib/python${PYTHON_VERSION%.*}/site-packages/max*.dist-info/METADATA | \
      sed "s|Requires-Dist: \(.*\)|\1|" | \
      cut -d ";" -f 1 | \
      sed "s|xgrammar==|xgrammar>=|g" | \
      tr -d "[:blank:]"); \
    pip install $packages; \
  else \
    pip install numpy; \
  fi \
  ## Clean up
  && apt-get -y purge cmake \
  && apt-get -y autoremove \
  && rm -rf ${HOME}/.cache \
    /tmp/magicenv \
    /tmp/magicenv.mod \
    /var/lib/apt/lists/*

ARG BUILD_START

ENV BUILD_DATE=${BUILD_START}

CMD ["mojo"]
