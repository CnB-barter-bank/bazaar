#!/bin/bash
set -e

cd /var/www/html

# --- 1. Генерируем .env через PHP ---
php -r "
\$skip = ['PATH','HOSTNAME','HOME','TERM','SHLVL','PWD','APACHE_DOCUMENT_ROOT'];
\$lines = [];
foreach (\$_ENV as \$k => \$v) {
    if (in_array(\$k, \$skip)) continue;
    \$v = str_replace(['\\\\', '\"'], ['\\\\\\\\', '\\\"'], \$v);
    \$lines[] = \$k.'=\"'.\$v.'\"';
}
file_put_contents('/var/www/html/.env', implode(\"\\n\", \$lines).\"\\n\");
"

# --- 2. APP_KEY ---
APP_KEY_VAL=$(php -r "\$e=parse_ini_file('.env'); echo \$e['APP_KEY'] ?? '';")
if [ -z "$APP_KEY_VAL" ]; then
    KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
    echo "APP_KEY=\"${KEY}\"" >> /var/www/html/.env
fi

# --- 3. Права на storage (КРИТИЧНО - до любого artisan) ---
mkdir -p storage/logs \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        bootstrap/cache

# Создаём лог-файл заранее от правильного владельца
touch storage/logs/laravel.log

# Рекурсивно назначаем www-data
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
chmod 664 storage/logs/laravel.log

# --- 4. Laravel bootstrap ---
php artisan package:discover --ansi 2>&1 || true
php artisan storage:link 2>/dev/null || true

# --- 5. Ждём MySQL и запускаем миграции ---
echo "Waiting for MySQL..."
for i in $(seq 1 30); do
    if php artisan migrate --force 2>&1; then
        echo "Migration done."
        break
    fi
    echo "Attempt $i: not ready, retry in 2s..."
    sleep 2
done

# --- 6. Финальный chown на случай если artisan создал новые файлы ---
chown -R www-data:www-data storage bootstrap/cache

exec apache2-foreground
