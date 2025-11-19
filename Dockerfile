FROM php:8.3-apache

WORKDIR /var/www/html

# Установка только самых необходимых зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    zip unzip \
    libzip-dev \
    libsqlite3-dev \
    && docker-php-ext-install \
        zip \
        pdo_sqlite \
        mysqli \
        pdo

# Включение mod_rewrite для Apache
RUN a2enmod rewrite

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Копируем код приложения
COPY . .

# Устанавливаем зависимости
RUN composer install --no-dev --optimize-autoloader

# Создаем базу данных SQLite
RUN mkdir -p database && touch database/database.sqlite

# Настраиваем права доступа
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/database
RUN chmod -R 775 storage bootstrap/cache database

# Настраиваем Apache для использования public директории
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Выполняем миграции
RUN php artisan migrate --force

# Кэшируем конфигурации для продакшена
RUN php artisan config:cache && \
    php artisan route:cache

EXPOSE 80

CMD ["apache2-foreground"]