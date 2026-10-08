# Portal Drupal Tutor TDS — imagem local/staging reproduzivel (Issue #163).
# Webroot separado: /var/www/html/web (drupal/recommended-project).
FROM php:8.3-apache

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

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . /var/www/html

# composer.lock e obrigatorio (Issue #163): falha de lock = falha de build.
RUN test -f composer.lock \
 && composer install --no-interaction --prefer-dist --no-progress --optimize-autoloader \
 && mkdir -p web/sites/default/files config/sync \
 && chmod -R 0777 web/sites/default/files config/sync

ENV PATH=/var/www/html/vendor/bin:$PATH
