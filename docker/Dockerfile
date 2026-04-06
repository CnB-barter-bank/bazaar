FROM php:8.2-apache

RUN apt-get update && apt-get install -y \
    pkg-config libzip-dev git unzip nodejs npm \
    && docker-php-ext-install mysqli pdo_mysql zip

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN a2enmod rewrite

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader
RUN npm install && npm run build

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 755 storage bootstrap/cache

CMD ["bash", "-c", "php artisan key:generate --no-interaction; php artisan storage:link; php artisan migrate --force; php artisan db:seed --force; apache2-foreground"]
