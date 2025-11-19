FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

FROM php:8.3-apache

ENV APACHE_DOCUMENT_ROOT /var/www/html/public

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip curl libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install pdo_mysql pdo_sqlite \
    && a2enmod rewrite headers

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/000-default.conf \
    /etc/apache2/apache2.conf

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && echo "LimitRequestFieldSize 65536" >> /etc/apache2/conf-enabled/limit-headers.conf \
    && echo "LimitRequestFields 100" >> /etc/apache2/conf-enabled/limit-headers.conf

COPY . .
COPY --from=vendor /app/vendor ./vendor

ARG APP_KEY
ARG APP_URL=https://maltsevnikitaju-yandexmaptest-back-2e25.twc1.net
ARG FRONTEND_URL=https://maltsevnikitaju-yandexmaptest-front-2e25.twc1.net
ARG SESSION_DOMAIN=maltsevnikitaju-yandexmaptest-back-2e25.twc1.net
ARG SESSION_COOKIE=yandex-map-test-session
ARG SANCTUM_STATEFUL_DOMAINS=maltsevnikitaju-yandexmaptest-front-2e25.twc1.net

RUN cp .env.example .env \
    && sed -ri "s|^APP_ENV=.*|APP_ENV=production|; \
s|^APP_URL=.*|APP_URL=${APP_URL}|; \
s|^FRONTEND_URL=.*|FRONTEND_URL=${FRONTEND_URL}|; \
s|^SESSION_DOMAIN=.*|SESSION_DOMAIN=${SESSION_DOMAIN}|; \
s|^SESSION_COOKIE=.*|SESSION_COOKIE=${SESSION_COOKIE}|; \
s|^SANCTUM_STATEFUL_DOMAINS=.*|SANCTUM_STATEFUL_DOMAINS=${SANCTUM_STATEFUL_DOMAINS}|" .env \
    && if [ -n \"${APP_KEY}\" ]; then sed -ri "s|^APP_KEY=.*|APP_KEY=${APP_KEY}|" .env; fi

RUN if [ -z "${APP_KEY}" ]; then php artisan key:generate --force; fi
RUN php artisan package:discover --ansi

RUN mkdir -p database && touch database/database.sqlite

RUN chown -R www-data:www-data storage bootstrap/cache database \
    && chmod -R 775 storage bootstrap/cache database

RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

EXPOSE 80

CMD ["apache2-foreground"]