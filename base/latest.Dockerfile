ARG BASE_IMAGE=debian
ARG BASE_IMAGE_TAG=12
ARG BUILD_ON_IMAGE=glcr.b-data.ch/python/ver
ARG MODULAR_VERSION
ARG MOJO_VERSION
ARG PYTHON_VERSION
ARG NEOVIM_VERSION=0.10.1
ARG GIT_VERSION=2.46.1
ARG GIT_LFS_VERSION=3.5.1
ARG PANDOC_VERSION=3.2

FROM glcr.b-data.ch/neovim/nvsi:${NEOVIM_VERSION} AS nvsi
FROM glcr.b-data.ch/git/gsi/${GIT_VERSION}/${BASE_IMAGE}:${BASE_IMAGE_TAG} AS gsi
FROM glcr.b-data.ch/git-lfs/glfsi:${GIT_LFS_VERSION} AS glfsi

FROM ${BUILD_ON_IMAGE}${PYTHON_VERSION:+:$PYTHON_VERSION} AS base

ARG DEBIAN_FRONTEND=noninteractive

ARG BUILD_ON_IMAGE
ARG MOJO_VERSION
ARG NEOVIM_VERSION
ARG GIT_VERSION
ARG GIT_LFS_VERSION
ARG PANDOC_VERSION

ENV PARENT_IMAGE=${BUILD_ON_IMAGE}${PYTHON_VERSION:+:$PYTHON_VERSION} \
    NEOVIM_VERSION=${NEOVIM_VERSION} \
    MODULAR_HOME=/opt/modular \
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
  && if [ -z "$PYTHON_VERSION" ]; then \
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
  ## Modular: Additional runtime dependencies
  && apt-get -y install --no-install-recommends \
    libtinfo-dev \
    libxml2-dev \
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

ARG MODULAR_VERSION
ARG MODULAR_NO_AUTH
ARG MODULAR_AUTH_KEY
ARG MOJO_VERSION
ARG MOJO_VERSION_FULL=${MOJO_VERSION}
ARG INSTALL_MAX

## Install Modular
RUN dpkgArch="$(dpkg --print-architecture)" \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    libtinfo-dev \
    libxml2-dev \
  && curl -sSL https://dl.modular.com/public/installer/deb/debian/pool/any-version/main/m/mo/modular_${MODULAR_VERSION}/modular-v${MODULAR_VERSION}-${dpkgArch}.deb \
    -o modular.deb \
  && dpkg --ignore-depends=python3,python3-pip,python3-venv -i modular.deb \
  && rm modular.deb \
  ## Clean up
  && rm -rf /var/lib/apt/lists/*

## Install Mojo or MAX
RUN modular config-set telemetry.enabled=false \
  && modular config-set telemetry.level=0 \
  && modular config-set crash_reporting.enabled=false \
  && if [ "${MODULAR_NO_AUTH}" != "1" ] && [ "${MODULAR_NO_AUTH}" != "true" ]; then \
    modular auth \
      "${MODULAR_AUTH_KEY:-$(echo -n "${NB_USER}" | sha256sum | cut -c -8)}"; \
  fi \
  && if [ "${INSTALL_MAX}" = "1" ] || [ "${INSTALL_MAX}" = "true" ]; then \
    if [ "${MOJO_VERSION}" = "nightly" ]; then \
      modular install nightly/max; \
    else \
      modular install --install-version "${MOJO_VERSION}" max; \
    fi \
  else \
    if [ "${MOJO_VERSION}" = "nightly" ]; then \
      modular install nightly/mojo; \
    else \
      modular install --install-version "${MOJO_VERSION_FULL}" mojo; \
    fi \
  fi \
  && chown -R root:${NB_GID} ${MODULAR_HOME} \
  && chmod -R g+w ${MODULAR_HOME} \
  && chmod -R g+rx ${MODULAR_HOME}/crashdb \
  ## Clean up
  && rm -rf ${MODULAR_HOME}/.*_cache

## Install the Mojo kernel for Jupyter
RUN mkdir -p /usr/local/share/jupyter/kernels \
  && mv ${HOME}/.local/share/jupyter/kernels/mojo* \
    /usr/local/share/jupyter/kernels/ \
  ## Fix Modular home in the Mojo kernel for Jupyter
  && grep -rl ${HOME}/.local /usr/local/share/jupyter/kernels/mojo* | \
    xargs sed -i "s|${HOME}/.local|/usr/local|g"

FROM base

ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION%%0*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%1*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%2*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%3*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%4*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%5*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%6*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%7*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%8*}
ARG MOJO_VERSION_NIGHTLY=${MOJO_VERSION_NIGHTLY%%9*}
ARG INSTALL_MAX

ARG MODULAR_PKG_BIN=${INSTALL_MAX:+$MODULAR_HOME/pkg/packages.modular.com${MOJO_VERSION_NIGHTLY:+_nightly}_max/bin}
ARG MODULAR_PKG_BIN=${MODULAR_PKG_BIN:-$MODULAR_HOME/pkg/packages.modular.com${MOJO_VERSION_NIGHTLY:+_nightly}_mojo/bin}

ENV PATH=${MODULAR_PKG_BIN}:$PATH

## Install Mojo or MAX
COPY --from=modular /opt /opt
## Install the Mojo kernel for Jupyter
COPY --from=modular /usr/local/share/jupyter /usr/local/share/jupyter

## Install the MAX Engine Python package or numpy
RUN export PIP_BREAK_SYSTEM_PACKAGES=1 \
  && if [ "${INSTALL_MAX}" = "1" ] || [ "${INSTALL_MAX}" = "true" ]; then \
    pip install --find-links \
      ${MODULAR_HOME}/pkg/packages.modular.com${MOJO_VERSION_NIGHTLY:+_nightly}_max/wheels max-engine; \
  else \
    pip install numpy; \
  fi \
  ## Clean up
  && rm -rf ${HOME}/.cache

ARG BUILD_START

ENV BUILD_DATE=${BUILD_START}

CMD ["mojo"]
