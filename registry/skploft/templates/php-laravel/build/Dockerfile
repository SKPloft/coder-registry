# syntax=docker/dockerfile:1.6
ARG PHP_VERSION=8.3
ARG NODE_MAJOR=20
ARG USER=coder
ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG NO_PROXY=

FROM ubuntu:24.04

ARG PHP_VERSION
ARG NODE_MAJOR
ARG USER
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

ENV HTTP_PROXY=${HTTP_PROXY} \
  HTTPS_PROXY=${HTTPS_PROXY} \
  NO_PROXY=${NO_PROXY} \
  http_proxy=${HTTP_PROXY} \
  https_proxy=${HTTPS_PROXY} \
  no_proxy=${NO_PROXY} \
  DEBIAN_FRONTEND=noninteractive \
  TZ=UTC \
  LANG=en_US.UTF-8 \
  LC_ALL=en_US.UTF-8

RUN test -z "${HTTP_PROXY}" || printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "${HTTP_PROXY}" "${HTTPS_PROXY}" > /etc/apt/apt.conf.d/01proxy

RUN printf 'Acquire::Retries "10";\nAcquire::http::Timeout "60";\nAcquire::https::Timeout "60";\n' > /etc/apt/apt.conf.d/80retries

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl git gnupg locales \
    sudo tzdata unzip zip \
  && locale-gen en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o /tmp/nodesource_setup.sh \
  && bash /tmp/nodesource_setup.sh \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -f /tmp/nodesource_setup.sh \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell=/bin/bash ${USER} \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
  && chmod 440 /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR /home/${USER}

# Herd Lite installs PHP (with bundled extensions), Composer, and the Laravel
# installer per-user under $HOME/.config/herd-lite/bin. Run as the coder user
# so it lands in /home/coder, not /root.
RUN /bin/bash -c "$(curl -fsSL https://php.new/install/linux/${PHP_VERSION})"

# The installer appends to ~/.bashrc, but non-login shells (Coder agent init,
# coder_script runs, docker exec) won't source it — set PATH explicitly.
ENV PATH="/home/${USER}/.config/herd-lite/bin:${PATH}"

CMD ["bash"]
