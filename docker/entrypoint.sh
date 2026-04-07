#!/bin/bash

# Сбрасываем ВСЕ переменные окружения в .env (кроме системных PATH и т.д.)
printenv | grep -v '^\(PATH\|HOSTNAME\|HOME\|TERM\|SHLVL\|PWD\|_=\|APACHE\|HTTPD\)' | while IFS='=' read -r key value; do
    echo "${key}=\"${value}\""
done > /var/www/html/.env

# Если APP_KEY не задан в env — генерируем сами и дописываем
if ! grep -q '^APP_KEY=' /var/www/html/.env || grep -q '^APP_KEY=""' /var/www/html/.env; then
    KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
    echo "APP_KEY=\"${KEY}\"" >> /var/www/html/.env
fi

# Права на storage
mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# package:discover
php artisan package:discover --ansi

# storage:link (игнорируем ошибку если уже есть)
php artisan storage:link 2>/dev/null || true

# Ждём MySQL (до 60 секунд)
echo "Waiting for MySQL..."
for i in $(seq 1 30); do
    if php artisan db:show > /dev/null 2>&1; then
        echo "MySQL is ready."
        break
    fi
    echo "Attempt $i: MySQL not ready, waiting 2s..."
    sleep 2
done

# migrate (не падаем если не получилось)
php artisan migrate --force 2>&1 || echo "Migration failed, continuing..."

# Запускаем Apache
exec apache2-foreground
