# MAX/Mojo docker stack

<!-- markdownlint-disable line-length -->
[![minimal-readme compliant](https://img.shields.io/badge/readme%20style-minimal-brightgreen.svg)](https://github.com/RichardLitt/standard-readme/blob/master/example-readmes/minimal-readme.md) [![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active) <a href="https://liberapay.com/benz0li/donate"><img src="https://liberapay.com/assets/widgets/donate.svg" alt="Donate using Liberapay" height="20"></a>
<!-- markdownlint-enable line-length -->

| See the [CUDA-based MAX docker stack](CUDA.md) for GPU accelerated docker images. |
|-----------------------------------------------------------------------------------|

Multi-arch (`linux/amd64`, `linux/arm64/v8`) docker images:

* [`glcr.b-data.ch/max/base`](https://gitlab.b-data.ch/max/base/container_registry)
* [`glcr.b-data.ch/max/scipy`](https://gitlab.b-data.ch/max/scipy/container_registry)
* [`glcr.b-data.ch/mojo/base`](https://gitlab.b-data.ch/mojo/base/container_registry)
* [`glcr.b-data.ch/mojo/scipy`](https://gitlab.b-data.ch/mojo/scipy/container_registry)

Images considered stable for Mojo versions ≥ 24.3.0.

**Build chain**

base → scipy

**Features**

These images are counterparts to the JupyterLab images but **without**

* code-server
* IPython
* JupyterHub
* JupyterLab
  * JupyterLab Extensions
  * JupyterLab Integrations
* Jupyter Notebook
  * Jupyter Notebook Conversion
* LSP Server
* Oh My Zsh
  * Powerlevel10k Theme
  * MesloLGS NF Font
* Widgets

and any configuration thereof.

:information_source: Regading [Magic/Pixi](https://docs.modular.com/pixi/), see
discussion [[(JupyterLab) MAX/Mojo docker stack] Why is Magic/Pixi not installed?](https://github.com/orgs/b-data/discussions/5)

## Table of Contents

* [Prerequisites](#prerequisites)
* [Install](#install)
* [Usage](#usage)
* [Contributing](#contributing)
* [Support](#support)
* [License](#license)

## Prerequisites

This projects requires an installation of docker.

## Install

To install docker, follow the instructions for your platform:

* [Install Docker Engine | Docker Documentation > Supported platforms](https://docs.docker.com/engine/install/#supported-platforms)
* [Post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/)

## Usage

### Build image (base)

nightly:

```shell
docker build \
  --build-arg MOJO_VERSION=nightly \
  --build-arg PYTHON_VERSION=3.13.9 \
  -t mojo/base:nightly \
  -f base/latest.Dockerfile .
```

latest:

```shell
docker build \
  --build-arg MOJO_VERSION=25.6.0 \
  --build-arg PYTHON_VERSION=3.13.9 \
  -t mojo/base \
  -f base/latest.Dockerfile .
```

version:

```shell
docker build \
  -t mojo/base:MAJOR.MINOR.PATCH \
  -f base/MAJOR.MINOR.PATCH.Dockerfile .
```

For `MAJOR.MINOR.PATCH` ≥ `24.3.0`.

### Run container

self built:

```shell
docker run -it --rm mojo/base[:MAJOR.MINOR.PATCH]
```

from the project's GitLab Container Registries:

```shell
docker run -it --rm IMAGE[:MAJOR[.MINOR[.PATCH]]]
```

`IMAGE` being one of

* [`glcr.b-data.ch/max/base`](https://gitlab.b-data.ch/max/base/container_registry)
* [`glcr.b-data.ch/max/scipy`](https://gitlab.b-data.ch/max/scipy/container_registry)
* [`glcr.b-data.ch/mojo/base`](https://gitlab.b-data.ch/mojo/base/container_registry)
* [`glcr.b-data.ch/mojo/scipy`](https://gitlab.b-data.ch/mojo/scipy/container_registry)

## Contributing

PRs accepted. Please submit to the
[GitLab repository](https://gitlab.com/b-data/mojo/docker-stack).

This project follows the
[Contributor Covenant](https://www.contributor-covenant.org)
[Code of Conduct](CODE_OF_CONDUCT.md).

## Support

Community support: Open a new discussion
[here](https://github.com/orgs/b-data/discussions).

Commercial support: Contact b-data by [email](mailto:support@b-data.ch).

## License

Copyright © 2024 b-data GmbH

Distributed under the terms of the [MIT License](LICENSE).
