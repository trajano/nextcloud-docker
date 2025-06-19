# DO NOT EDIT: created by update.sh from Dockerfile-debian.template
FROM --platform=$BUILDPLATFORM alpine AS extract
WORKDIR /usr/src/
WORKDIR /var/www/html/
RUN --mount=type=cache,target=/var/cache/apk apk -U add bzip2 gnupg 
ADD "https://download.nextcloud.com/server/releases/nextcloud-30.0.13.tar.bz2" /var/www/html/nextcloud.tar.bz2
ADD "https://download.nextcloud.com/server/releases/nextcloud-30.0.13.tar.bz2.asc" /var/www/html/nextcloud.tar.bz2.asc
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
# gpg key from https://nextcloud.com/nextcloud.asc
    gpg --batch --keyserver keyserver.ubuntu.com  --recv-keys 28806A878AE423A28372792ED75899B9A724937A; \
    gpg --batch --verify nextcloud.tar.bz2.asc nextcloud.tar.bz2; \
    tar -xjf nextcloud.tar.bz2 -C /usr/src/; \
    gpgconf --kill all; \
    rm nextcloud.tar.bz2.asc nextcloud.tar.bz2; \
    rm -rf "$GNUPGHOME" /usr/src/nextcloud/updater; \
    mkdir -p /usr/src/nextcloud/data; \
    mkdir -p /usr/src/nextcloud/custom_apps; \
    chmod +x /usr/src/nextcloud/occ;

FROM caddy:builder AS caddy-builder
RUN --mount=type=cache,target=/go/pkg/mod/cache xcaddy build \
  --with github.com/caddyserver/caddy/v2=github.com/trajano/caddy/v2@otel-client \
  --with github.com/caddyserver/cache-handler \
  --with github.com/darkweak/storages/nuts/caddy \
  --with github.com/darkweak/storages/redis/caddy

FROM scratch AS create-extra-files
# To keep it simple just write in multiple layers

# Create necessary folders using WORKDIR
WORKDIR /var/spool/cron/crontabs
WORKDIR /tmp/conf.d

# see https://docs.nextcloud.com/server/stable/admin_manual/installation/source_installation.html
ENV PHP_MEMORY_LIMIT=512M
ENV PHP_UPLOAD_LIMIT=512M
ENV PHP_OPCACHE_MEMORY_CONSUMPTION=128

# set recommended PHP.ini settings
# see https://docs.nextcloud.com/server/latest/admin_manual/installation/server_tuning.html#enable-php-opcache
COPY <<EOF /var/spool/cron/crontabs/www-data
*/5 * * * * php -f /var/www/html/cron.php
EOF

COPY <<EOF /tmp/conf.d/opcache-recommended.ini
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=32
opcache.max_accelerated_files=10000
opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}
opcache.save_comments=1
opcache.file_cache=/var/cache/php/opcache
opcache.revalidate_freq=60
opcache.jit=1255
opcache.jit_buffer_size=8M
EOF

COPY <<EOF /tmp/conf.d/docker-php-ext-apcu-ext.ini
apc.enable_cli=1
EOF

COPY <<EOF /tmp/conf.d/docker-php-ext-igbinary-ext.ini
apc.serializer=igbinary
session.serialize_handler=igbinary
EOF

COPY <<EOF /tmp/conf.d/nextcloud.ini
memory_limit=${PHP_MEMORY_LIMIT}
upload_max_filesize=${PHP_UPLOAD_LIMIT}
post_max_size=${PHP_UPLOAD_LIMIT}
EOF

FROM php:8.4-fpm-bookworm AS basepackages
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=private \
    --mount=type=cache,target=/var/cache/apt,sharing=private \
    --mount=type=tmpfs,target=/var/log/apt \
    set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        busybox-static \
        bzip2 \
        libldap-common \
        libmagickcore-6.q16-6-extra \
        rsync \
        ffmpeg \
        libgd3 \
        exiftool \
        libzip4 \
        libpq5 \
        libmemcached11; \
    apt-get upgrade -y;


FROM php:8.4-fpm-bookworm AS devlibs
# Build the PHP modules.  This will not perform any intermediate image cleanup since
# only the /usr/local/lib/php will be copied.  It also uses fpm variant since so that it can leverage the build cache better.

# install the PHP extensions we need
# see https://docs.nextcloud.com/server/stable/admin_manual/installation/source_installation.html
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=private \
    --mount=type=cache,target=/var/cache/apt,sharing=private \
    --mount=type=tmpfs,target=/var/log/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev \
        libevent-dev \
        libgd-dev \
        libgmp-dev \
        libicu-dev \
        libldap2-dev \
        libmagickwand-dev \
        libmcrypt-dev \
        libmemcached-dev \
        libpq-dev \
        libssl-dev \
        libxml2-dev \
        libzip-dev

FROM devlibs AS modules

RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" bcmath
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" exif
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-configure ftp --with-ftp-ssl && \
    docker-php-ext-install -j "$(nproc)" ftp
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif --with-xpm && \
    docker-php-ext-install -j "$(nproc)" gd
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" gmp
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" intl
RUN --mount=type=tmpfs,target=/tmp \
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" && \
    docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch" && \
    docker-php-ext-install -j "$(nproc)" ldap
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" opcache
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" pcntl
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" pdo_mysql
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" pdo_pgsql
RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-install -j "$(nproc)" sysvsem

RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-configure zip --with-zip && \
    docker-php-ext-install -j "$(nproc)" zip

# pecl will claim success even if one install fails, so we need to perform each install separately
RUN --mount=type=tmpfs,target=/tmp pecl install APCu-5.1.24
RUN --mount=type=tmpfs,target=/tmp pecl install igbinary-3.2.16
RUN --mount=type=tmpfs,target=/tmp pecl install imagick-3.8.0
RUN --mount=type=tmpfs,target=/tmp pecl install memcached-3.3.0 --configureoptions 'enable-memcached-igbinary="yes"'
RUN --mount=type=tmpfs,target=/tmp pecl install redis-6.2.0 --configureoptions 'enable-redis-igbinary="yes" enable-redis-zstd="yes" enable-redis-lz4="yes"'

RUN --mount=type=tmpfs,target=/tmp \
    docker-php-ext-enable \
        apcu \
        igbinary \
        imagick \
        memcached \
        redis \
    ;

# Build modules in parallel note no -j since Docker will be splitting the builds already
FROM php:8.4-fpm-bookworm AS module-bcmath
RUN docker-php-ext-install bcmath

FROM php:8.4-fpm-bookworm AS module-exif
RUN docker-php-ext-install exif

FROM devlibs AS module-ftp
RUN docker-php-ext-configure ftp --with-ftp-ssl && \
    docker-php-ext-install ftp

FROM devlibs AS module-gd
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif --with-xpm && \
    docker-php-ext-install gd

FROM devlibs AS module-gmp
RUN docker-php-ext-install gmp

FROM devlibs AS module-intl
RUN docker-php-ext-install intl

FROM devlibs AS module-ldap
RUN debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" && \
    docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch" && \
    docker-php-ext-install ldap

FROM php:8.4-fpm-bookworm AS module-opcache
RUN docker-php-ext-install opcache

FROM php:8.4-fpm-bookworm AS module-pcntl
RUN docker-php-ext-install pcntl

FROM devlibs AS module-pdo_mysql
RUN docker-php-ext-install pdo_mysql

FROM devlibs AS module-pdo_pgsql
RUN docker-php-ext-install pdo_pgsql

FROM php:8.4-fpm-bookworm AS module-sysvsem
RUN docker-php-ext-install sysvsem

FROM devlibs AS module-zip
RUN docker-php-ext-configure zip --with-zip && \
    docker-php-ext-install zip

FROM devlibs AS module-apcu
RUN pecl install APCu-5.1.24 && \
    docker-php-ext-enable apcu

FROM devlibs AS module-igbinary
RUN pecl install igbinary-3.2.16 && \
    docker-php-ext-enable igbinary

FROM devlibs AS module-imagemagick
RUN pecl install imagick-3.8.0 && \
    docker-php-ext-enable imagick

FROM devlibs AS module-memcached
RUN pecl install memcached-3.3.0 --configureoptions 'enable-memcached-igbinary="yes"' && \
    docker-php-ext-enable memcached

FROM devlibs AS module-redis
RUN pecl install redis-6.2.0 --configureoptions 'enable-redis-igbinary="yes" enable-redis-zstd="yes" enable-redis-lz4="yes"' && \
    docker-php-ext-enable redis

FROM scratch AS modules2
COPY --from=module-apcu /usr/local/lib/php/     /usr/local/lib/php/
COPY --from=module-apcu /usr/local/etc/php/     /usr/local/etc/php/
COPY --from=module-bcmath /usr/local/lib/php/   /usr/local/lib/php/
COPY --from=module-bcmath /usr/local/etc/php/   /usr/local/etc/php/
COPY --from=module-exif /usr/local/lib/php/     /usr/local/lib/php/
COPY --from=module-exif /usr/local/etc/php/     /usr/local/etc/php/
COPY --from=module-ftp /usr/local/lib/php/      /usr/local/lib/php/
COPY --from=module-ftp /usr/local/etc/php/      /usr/local/etc/php/
COPY --from=module-gd /usr/local/lib/php/       /usr/local/lib/php/
COPY --from=module-gd /usr/local/etc/php/       /usr/local/etc/php/
COPY --from=module-gmp /usr/local/lib/php/      /usr/local/lib/php/
COPY --from=module-gmp /usr/local/etc/php/      /usr/local/etc/php/
COPY --from=module-igbinary /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=module-igbinary /usr/local/etc/php/ /usr/local/etc/php/
COPY --from=module-imagemagick /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=module-imagemagick /usr/local/etc/php/ /usr/local/etc/php/
COPY --from=module-intl /usr/local/lib/php/     /usr/local/lib/php/
COPY --from=module-intl /usr/local/etc/php/     /usr/local/etc/php/
COPY --from=module-ldap /usr/local/lib/php/     /usr/local/lib/php/
COPY --from=module-ldap /usr/local/etc/php/     /usr/local/etc/php/
COPY --from=module-memcached /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=module-memcached /usr/local/etc/php/ /usr/local/etc/php/
COPY --from=module-opcache /usr/local/lib/php/  /usr/local/lib/php/
COPY --from=module-opcache /usr/local/etc/php/  /usr/local/etc/php/
COPY --from=module-pcntl /usr/local/lib/php/    /usr/local/lib/php/
COPY --from=module-pcntl /usr/local/etc/php/    /usr/local/etc/php/
COPY --from=module-pdo_mysql /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=module-pdo_mysql /usr/local/etc/php/ /usr/local/etc/php/
COPY --from=module-pdo_pgsql /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=module-pdo_pgsql /usr/local/etc/php/ /usr/local/etc/php/
COPY --from=module-redis /usr/local/lib/php/     /usr/local/lib/php/
COPY --from=module-redis /usr/local/etc/php/     /usr/local/etc/php/
COPY --from=module-sysvsem /usr/local/lib/php/   /usr/local/lib/php/
COPY --from=module-sysvsem /usr/local/etc/php/   /usr/local/etc/php/
COPY --from=module-zip /usr/local/lib/php/       /usr/local/lib/php/
COPY --from=module-zip /usr/local/etc/php/       /usr/local/etc/php/

FROM --platform=$BUILDPLATFORM basepackages AS precompile
COPY --from=modules /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=modules /usr/local/etc/php/ /usr/local/etc/php/
# Skip include since we don't need the C headers
COPY --from=extract /usr/src/nextcloud/ /usr/src/nextcloud/
WORKDIR /var/cache/php/opcache

RUN find /var/www/html \
    -type f \
    -name "*.php" \
    -exec php \
        -d opcache.file_cache=/var/cache/php/opcache \
        -d opcache.enable_file_override=0 \
        -d opcache.file_cache_only=1 \
        -d opcache.enable_cli=1 \
        -d opcache.memory_consumption=1024 \
        -d opcache.enable=1 \
        -l  \
        -f {} \;

FROM basepackages
COPY --from=modules /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=modules /usr/local/etc/php/ /usr/local/etc/php/
# Skip include since we don't need the C headers
COPY --from=extract /usr/src/nextcloud/ /usr/src/nextcloud/

# Create the directories using Dockerfile rather than mkdir
WORKDIR /var/www/data
WORKDIR /var/log/php
WORKDIR /docker-entrypoint-hooks.d/pre-installation
WORKDIR /docker-entrypoint-hooks.d/post-installation
WORKDIR /docker-entrypoint-hooks.d/pre-upgrade
WORKDIR /docker-entrypoint-hooks.d/post-upgrade
WORKDIR /docker-entrypoint-hooks.d/before-starting
WORKDIR /var/www/html

# install the PHP extensions we need
# see https://docs.nextcloud.com/server/stable/admin_manual/installation/source_installation.html
ENV PHP_MEMORY_LIMIT=512M
ENV PHP_UPLOAD_LIMIT=512M
ENV PHP_OPCACHE_MEMORY_CONSUMPTION=128

# set recommended PHP.ini settings
# see https://docs.nextcloud.com/server/latest/admin_manual/installation/server_tuning.html#enable-php-opcache

VOLUME /var/www/html


ENV NEXTCLOUD_VERSION=30.0.13

COPY --from=create-extra-files /var/spool/cron/crontabs/www-data /var/spool/cron/crontabs/www-data
COPY --from=create-extra-files /tmp/conf.d/* ${PHP_INI_DIR}/conf.d/
COPY --chmod=0755 --chown=root:root *.sh /
COPY --chmod=0644 --chown=root:root upgrade.exclude /
COPY config/* /usr/src/nextcloud/config/
COPY --from=caddy-builder --chmod=755 --chown=root:root /usr/bin/caddy /usr/bin/caddy
COPY --from=precompile --chmod=0664 --chown=www-data:www-data /var/cache/php/opcache /var/cache/php/opcache
COPY --chmod=0644 --chown=root:root Caddyfile /etc/caddy/Caddyfile

COPY <<EOF /usr/local/etc/php-fpm.d/zzz-max-children.conf
[www]
pm.max_children = 20
EOF

RUN chown -R www-data:root /var/www;
ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
