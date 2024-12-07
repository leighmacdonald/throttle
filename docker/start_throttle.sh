#!/usr/bin/env bash

cron -f &

php app/console.php migrations:migrate
docker-php-entrypoint php-fpm
