FROM php:7-fpm
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

RUN apt update  \
    && apt install -y  \
      procps \
      cron \
      sudo \
      git  \
      unzip  \
      libfreetype-dev \
      libjpeg62-turbo-dev \
      libpng-dev \
      rrdtool \
      munin \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo pdo_mysql gmp ctype \
    && pecl install apcu \
    && pecl install apcu_bc \
    && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
    && docker-php-ext-enable apc --ini-name 20-docker-php-ext-apc.ini \
    && docker-php-ext-enable gmp \
    && docker-php-ext-enable ctype \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo '%www-data ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY ./docker/cron /etc/cron.d/cron

RUN chmod 0644 /etc/cron.d/cron \
    && crontab -u www-data  /etc/cron.d/cron \
    && chmod u+s /usr/sbin/cron \
    && touch /var/log/cron.log

COPY ./docker/start_throttle.sh /app/

WORKDIR /app
COPY ../composer.json ../composer.json ./

COPY .. .
RUN chown -R www-data:www-data /app && chown www-data /var/www
USER www-data

EXPOSE 9000

# Can randomly fail trying to download git repo using internal php based git client
# Not sure of a proper fix, but just run it until it works for now ¯\_(ツ)_/¯.
RUN composer install

#RUN php app/console.php migrations:migrate
ENTRYPOINT ./start_throttle.sh
