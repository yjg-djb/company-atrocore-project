FROM php:8.4-apache-bookworm AS base
LABEL maintainer="yjg-djb"

ARG BUILD_VARIANT=base

RUN sed -i 's|http://deb.debian.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g; s|http://deb.debian.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list.d/debian.sources \
    && printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80-retries \
    && pecl channel-update pecl.php.net \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && printf "\npost_max_size = 20M\nupload_max_filesize = 20M\nmax_execution_time = 180\nmax_input_time = 180\nmemory_limit = 256M\n" >> "$PHP_INI_DIR/php.ini" \
    && apt-get update && apt-get install -y --no-install-recommends \
        git \
        cron \
        postgresql-client \
        zip unzip \
        build-essential \
        locales \
        libcurl4 \
        libcurl4-openssl-dev \
        libsodium-dev \
        libfreetype-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libpq-dev \
        libavif-dev \
        libattr1-dev \
        libonig-dev \
        libzip-dev \
        zlib1g-dev \
        libmagickwand-dev \
        libldap2-dev \
        libldap-common \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-avif \
    && docker-php-ext-install -j"$(nproc)" mbstring curl gd xml zip pdo_pgsql exif ftp ldap sockets \
    && pecl install xattr \
    && (pecl install imagick || pecl install imagick || pecl install imagick) \
    && docker-php-ext-enable xattr imagick \
    && a2enmod rewrite \
    && a2dissite 000-default \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/localhost

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY . /var/www/localhost

RUN sed -i 's/\r$//' .docker/startup.sh \
    && chmod +x .docker/startup.sh \
    && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader \
    && mkdir -p data/cache data/logs data/migrations upload/files upload/thumbnails \
    && chown -R www-data:www-data /var/www/localhost

COPY .docker/apache/localhost.conf /etc/apache2/sites-available/localhost.conf
RUN a2ensite localhost

USER root

CMD ["/var/www/localhost/.docker/startup.sh"]

FROM base AS pdf

RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium \
        chromium-driver \
        libreoffice-core \
        libreoffice-writer \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/chromium /usr/bin/google-chrome
