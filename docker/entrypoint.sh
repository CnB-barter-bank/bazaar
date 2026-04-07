#!/bin/bash

cd /var/www/html

# Генерируем .env через PHP - он правильно экранирует значения
php -r "
\$skip = ['PATH','HOSTNAME','HOME','TERM','SHLVL','PWD','APACHE_DOCUMENT_ROOT'];
\$lines = [];
foreach (\$_ENV as \$k => \$v) {
    if (in_array(\$k, \$skip)) continue;
    // Экранируем спецсимволы
    \$v = str_replace(['\\\\', '\"'], ['\\\\\\\\', '\\\"'], \$v);
    \$lines[] = \$k.'=\"'.\$v.'\"';
}
file_put_contents('/var/www/html/.env', implode(\"\\n\", \$lines).\"\\n\");
"

# Если APP_KEY не задан или пустой - генерируем
APP_KEY_VAL=$(php -r "\$e=parse_ini_file('.env'); echo \$e['APP_KEY'] ?? '';")
if [ -z "$APP_KEY_VAL" ]; then
    KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
    echo "APP_KEY=\"${KEY}\"" >> /var/www/html/.env
fi

# Права на storage
mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Laravel bootstrap
php artisan package:discover --ansi
php artisan storage:link 2>/dev/null || true

# Ждём MySQL до 60 секунд
echo "Waiting for MySQL..."
for i in $(seq 1 30); do
    if php artisan migrate --force > /dev/null 2>&1; then
        echo "Migration done."
        break
    fi
    echo "Attempt $i: DB not ready, waiting 2s..."
    sleep 2
done

exec apache2-foreground
