# Portal Drupal Tutor TDS — imagem local/staging reproduzivel (Issue #163).
# Webroot separado: /var/www/html/web (drupal/recommended-project).
#
# Bases pinadas por digest imutavel revisado em 2026-10-08 (review ACP PR #177):
#   php:8.3-apache  e composer:2  abaixo; mariadb:11.8 nos arquivos compose.
# Limite de reprodutibilidade declarado: os pacotes APT instalados no primeiro
# RUN sao resolvidos do repositorio Debian corrente no momento do build e NAO
# sao bit-for-bit reproduziveis — o digest fixa apenas o snapshot da imagem
# base. Pacotes PHP/Composer sao reproduziveis via composer.lock obrigatorio.
FROM composer:2@sha256:af98f42dfff7c68ba8d53c2164fd9fde1087b7d449514baa38c418b1f6bc4bac AS composer-bin

FROM php:8.3-apache@sha256:7a33fa6c555763fa384c727ab7377c4807f628daec0660eda705957a905f707f

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      curl \
      git \
      unzip \
      mariadb-client \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libzip-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" gd pdo_mysql zip opcache \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite headers

# Webroot separado conforme drupal/recommended-project.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
 && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}/!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

RUN { \
      echo 'memory_limit=512M'; \
      echo 'upload_max_filesize=32M'; \
      echo 'post_max_size=32M'; \
      echo 'max_execution_time=120'; \
      echo 'opcache.enable=1'; \
      echo 'opcache.validate_timestamps=1'; \
      echo 'opcache.revalidate_freq=0'; \
    } > /usr/local/etc/php/conf.d/tds-portal.ini

COPY --from=composer-bin /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . /var/www/html

# composer.lock e obrigatorio (Issue #163): falha de lock = falha de build.
# Diretorios gravaveis: dono www-data (usuario do Apache), sem permissao world.
RUN test -f composer.lock \
 && composer install --no-interaction --prefer-dist --no-progress --optimize-autoloader \
 && mkdir -p web/sites/default/files config/sync \
 && chown -R www-data:www-data web/sites/default/files config/sync \
 && find web/sites/default/files config/sync -type d -exec chmod 2775 {} + \
 && find web/sites/default/files config/sync -type f -exec chmod 0664 {} +

ENV PATH=/var/www/html/vendor/bin:$PATH
