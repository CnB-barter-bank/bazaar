#!/bin/bash
set -e

# Генерируем .env из переменных окружения Coolify
env | grep -E '^(APP_|DB_|CACHE_|QUEUE_|SESSION_|REDIS_|MAIL_|AWS_|PUSHER_|VITE_|LOG_|BROADCAST_|FILESYSTEM_|MEMCACHED_|FLUTTERWAVE_|PAYSTACK_|RECAPTCHA_)' | sed 's/=\(.*\)/="\1"/' > /var/www/html/.env

# Права на storage
mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Laravel bootstrap
php artisan key:generate --no-interaction
php artisan package:discover --ansi
php artisan storage:link
php artisan migrate --force

# Запускаем Apache
exec apache2-foreground
