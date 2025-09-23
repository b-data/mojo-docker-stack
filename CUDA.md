# CUDA-based MAX docker stack

GPU accelerated, multi-arch (`linux/amd64`, `linux/arm64/v8`) docker images:

* [`glcr.b-data.ch/cuda/max/base`](https://gitlab.b-data.ch/cuda/max/base/container_registry)
* [`glcr.b-data.ch/cuda/max/scipy`](https://gitlab.b-data.ch/cuda/max/scipy/container_registry)

Images available for MAX versions ≥ 24.6.0.

**Build chain**

The same as the [MAX/Mojo docker stack](README.md#maxmojo-docker-stack).

**Features**

The same as the [MAX/Mojo docker stack](README.md#maxmojo-docker-stack) plus the
CUDA runtime.

## Table of Contents

* [Prerequisites](#prerequisites)
* [Install](#install)
* [Usage](#usage)

## Prerequisites

The same as the [MAX/Mojo docker stack](README.md#prerequisites) plus

* NVIDIA GPU
* NVIDIA Linux driver
* NVIDIA Container Toolkit

:information_source: The host running the GPU accelerated images only requires
the NVIDIA driver, the CUDA toolkit does not have to be installed.

## Install

To install the NVIDIA Container Toolkit, follow the instructions for your
platform:

* [Installation Guide &mdash; NVIDIA Cloud Native Technologies documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#supported-platforms)

## Usage

### Build image (base)

nightly:

```shell
docker build \
  --build-arg BASE_IMAGE=ubuntu \
  --build-arg BASE_IMAGE_TAG=24.04 \
  --build-arg BUILD_ON_IMAGE=glcr.b-data.ch/cuda/python/ver \
  --build-arg MOJO_VERSION=nightly \
  --build-arg PYTHON_VERSION=3.13.7 \
  --build-arg CUDA_IMAGE_FLAVOR=base \
  --build-arg INSTALL_MAX=1 \
  -t cuda/max/base:nightly \
  -f base/latest.Dockerfile .
```

latest:

```shell
docker build \
  --build-arg BASE_IMAGE=ubuntu \
  --build-arg BASE_IMAGE_TAG=24.04 \
  --build-arg BUILD_ON_IMAGE=glcr.b-data.ch/cuda/python/ver \
  --build-arg MOJO_VERSION=25.6.0 \
  --build-arg PYTHON_VERSION=3.13.7 \
  --build-arg CUDA_IMAGE_FLAVOR=base \
  --build-arg INSTALL_MAX=1 \
  -t cuda/max/base \
  -f base/latest.Dockerfile .
```

version:

```shell
docker build \
  --build-arg BASE_IMAGE=ubuntu \
  --build-arg BASE_IMAGE_TAG=24.04 \
  --build-arg BUILD_ON_IMAGE=glcr.b-data.ch/cuda/python/ver \
  --build-arg CUDA_IMAGE_FLAVOR=base \
  --build-arg INSTALL_MAX=1 \
  -t cuda/max/base:MAJOR.MINOR.PATCH \
  -f base/MAJOR.MINOR.PATCH.Dockerfile .
```

For `MAJOR.MINOR.PATCH` ≥ `24.6.0`.

### Run container

self built:

```shell
docker run -it --rm \
  --gpus '"device=all"' \
  cuda/max/base[:MAJOR.MINOR.PATCH]
```

from the project's GitLab Container Registries:

```shell
docker run -it --rm \
  --gpus '"device=all"' \
  IMAGE[:MAJOR[.MINOR[.PATCH]]]
```

`IMAGE` being one of

* [`glcr.b-data.ch/cuda/max/base`](https://gitlab.b-data.ch/cuda/max/base/container_registry)
* [`glcr.b-data.ch/cuda/max/scipy`](https://gitlab.b-data.ch/cuda/max/scipy/container_registry)

The CUDA-based MAX docker stack is derived from the CUDA-based Python docker
stack.  
:information_source: See also [Python docker stack > Notes on CUDA](https://github.com/b-data/python-docker-stack/blob/main/CUDA_NOTES.md).
