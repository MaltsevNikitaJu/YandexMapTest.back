FROM php:8.3-fpm

WORKDIR /var/www/html

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    zip unzip \
    libzip-dev \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    && docker-php-ext-install \
        zip \
        pdo_sqlite \
        curl \
        xml \
        mbstring \
        tokenizer \
        ctype \
        json

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Копируем код приложения
COPY . .

# Устанавливаем зависимости
RUN composer install --no-dev --optimize-autoloader

# Создаем базу данных
RUN mkdir -p database && touch database/database.sqlite

# Настраиваем права
RUN chown -R www-data:www-data storage bootstrap/cache database
RUN chmod -R 775 storage bootstrap/cache database

# Генерируем ключ и запускаем миграции
RUN php artisan key:generate --force
RUN php artisan migrate --force

# Кэшируем для продакшена
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache

EXPOSE 9000

CMD ["php-fpm"]