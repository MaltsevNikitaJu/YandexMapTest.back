FROM php:8.3-apache

WORKDIR /var/www/html

RUN apt-get update && apt-get install -y curl unzip
RUN a2enmod rewrite
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY . .

RUN composer install --no-dev --optimize-autoloader

RUN mkdir -p database && touch database/database.sqlite
RUN chown -R www-data:www-data storage bootstrap/cache database
RUN chmod -R 775 storage bootstrap/cache database

ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf

RUN php artisan migrate --force

RUN php artisan config:clear
RUN php artisan route:clear
RUN php artisan view:clear


EXPOSE 80

CMD ["apache2-foreground"]