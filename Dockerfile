FROM php:8.3-apache

WORKDIR /var/www/html

# Установка зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    sqlite3 \
    && docker-php-ext-install pdo pdo_sqlite

# Включение mod_rewrite и настройка ServerName
RUN a2enmod rewrite
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Установка Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Копируем код
COPY . .

# Устанавливаем зависимости
RUN composer install --no-dev --optimize-autoloader

# Создаем базу данных
RUN mkdir -p database && touch database/database.sqlite

# Права доступа
RUN chown -R www-data:www-data storage bootstrap cache database
RUN chmod -R 775 storage bootstrap cache database

# Настройка Apache
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf

# Создаем .env из переменных окружения (важно!)
RUN printenv | grep -E "^(APP|DB|SESSION|SANCTUM)_" > .env

# Laravel команды
RUN php artisan migrate --force
RUN php artisan config:clear
RUN php artisan cache:clear

EXPOSE 80

CMD ["apache2-foreground"]