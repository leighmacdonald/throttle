FROM php:7.4-apache

# Prevent interactive prompts during package installation.
ENV DEBIAN_FRONTEND=noninteractive

# System deps:
#  - git/unzip for composer + libphutil version lookup (`git describe`)
#  - libgmp-dev: Crash::submit() uses gmp_* functions
#  - libzip-dev: zip extension for composer/symbols handling
# NOTE: no mysql-client on purpose: bullseye's mariadb-common package is
# currently uninstallable (404) and the entrypoint waits via PHP/PDO instead.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libgmp-dev \
        libzip-dev \
        libonig-dev \
        rrdtool \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gmp \
        mbstring \
        zip \
        opcache \
    && pecl install redis-5.3.7 apcu-5.1.22 \
    && docker-php-ext-enable redis apcu opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Composer (handles the legacy silex/symfony 2.3 dependency tree).
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/throttle

# Install PHP dependencies first for better layer caching.
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-progress --prefer-dist --no-interaction || \
    composer install --no-dev --no-scripts --no-progress --prefer-dist --no-interaction --ignore-platform-reqs

# Copy the application.
COPY . .

# Make sure composer autoloader matches the vendored code (e.g. after the
# facebook/libphutil -> phacility/libphutil path fix).
RUN composer dump-autoload --no-dev --optimize --no-interaction || true

# Breakpad helper binaries.
RUN chmod +x bin/minidump_stackwalk bin/carburetor bin/dump_syms bin/breakpad_moduleid bin/nm 2>/dev/null || true

# Writable directories (README: chmod -R a+w logs cache dumps symbols/public).
RUN mkdir -p logs cache/profiler cache/symbols dumps symbols/public \
    && chmod -R a+w logs cache dumps symbols \
    && chown -R www-data:www-data logs cache dumps symbols

# Apache vhost + PHP tweaks.
COPY docker/apache-throttle.conf /etc/apache2/sites-available/000-default.conf
COPY docker/php-throttle.ini /usr/local/etc/php/conf.d/throttle.ini

# Entrypoint generates app/config.php from env, waits for db/redis,
# runs migrations, fixes perms, then starts Apache.
COPY docker/docker-entrypoint.sh /usr/local/bin/throttle-entrypoint.sh
# RRD graph updater (munin-plugin -> munin-compatible .rrd files)
# + PNG renderer (RRDs -> web/munin-graphs/*.png for /munin-graphs URLs).
COPY docker/munin-update.sh /usr/local/bin/munin-update.sh
COPY docker/munin-graph.sh /usr/local/bin/munin-graph.sh
COPY docker/throttle-graphs.sh /usr/local/bin/throttle-graphs.sh
RUN chmod +x /usr/local/bin/throttle-entrypoint.sh /usr/local/bin/munin-update.sh /usr/local/bin/munin-graph.sh /usr/local/bin/throttle-graphs.sh

EXPOSE 80

ENTRYPOINT ["throttle-entrypoint.sh"]
CMD ["apache2-foreground"]
