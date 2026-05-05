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

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates curl git gnupg locales lsb-release \
    software-properties-common sudo tzdata unzip zip \
  && locale-gen en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository -y ppa:ondrej/php \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-dom \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
  && update-alternatives --set php /usr/bin/php${PHP_VERSION} \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://getcomposer.org/installer | php -- \
  --install-dir=/usr/local/bin --filename=composer

RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" -o /tmp/nodesource_setup.sh \
  && bash /tmp/nodesource_setup.sh \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -f /tmp/nodesource_setup.sh \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell=/bin/bash ${USER} \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
  && chmod 440 /etc/sudoers.d/${USER}

WORKDIR /home/${USER}
USER ${USER}
CMD ["bash"]
