FROM php:8.3-cli

WORKDIR /app

# Копируем только нужные файлы
COPY . .

# Устанавливаем зависимости
RUN apt-get update && apt-get install -y \
    curl zip unzip libzip-dev libsqlite3-dev \
    && docker-php-ext-install zip pdo_sqlite

# Устанавливаем Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Устанавливаем зависимости
RUN composer install --no-dev --optimize-autoloader

# СОЗДАЕМ ПРАВИЛЬНЫЙ .env АВТОМАТИЧЕСКИ
RUN cat > .env << 'EOF'
APP_NAME="Yandex Map Test Backend"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://maltsevnikitaju-yandexmaptest-back-ce11.twc1.net

DB_CONNECTION=sqlite
DB_DATABASE=/app/database/database.sqlite

SESSION_DRIVER=cookie
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null
SESSION_SECURE_COOKIE=true
SESSION_SAME_SITE=none

SANCTUM_STATEFUL_DOMAINS=maltsevnikitaju-yandexmaptest-front-2e25.twc1.net,localhost:5173

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=database

CACHE_STORE=database

MAIL_MAILER=log
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"
EOF

# СОЗДАЕМ CORS КОНФИГ АВТОМАТИЧЕСКИ
RUN cat > config/cors.php << 'EOF'
<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'login', 'logout', 'register'],

    'allowed_methods' => ['*'],

    'allowed_origins' => [
        'https://maltsevnikitaju-yandexmaptest-front-2e25.twc1.net',
        'http://localhost:5173'
    ],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => true,
];
EOF

# СОЗДАЕМ CORS MIDDLEWARE АВТОМАТИЧЕСКИ
RUN mkdir -p app/Http/Middleware
RUN cat > app/Http/Middleware/Cors.php << 'EOF'
<?php

namespace App\Http\Middleware;

use Closure;

class Cors
{
    public function handle($request, Closure $next)
    {
        $allowedOrigins = [
            'https://maltsevnikitaju-yandexmaptest-front-2e25.twc1.net',
            'http://localhost:5173'
        ];

        $origin = $request->header('Origin');

        if (in_array($origin, $allowedOrigins)) {
            $response = $next($request);
            
            $response->headers->set('Access-Control-Allow-Origin', $origin);
            $response->headers->set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
            $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, X-CSRF-TOKEN, X-XSRF-TOKEN');
            $response->headers->set('Access-Control-Allow-Credentials', 'true');
            $response->headers->set('Access-Control-Max-Age', '86400');
            
            return $response;
        }

        return $next($request);
    }
}
EOF

# ОБНОВЛЯЕМ KERNEL ДЛЯ CORS
RUN cat > app/Http/Kernel.php << 'EOF'
<?php

namespace App\Http;

use Illuminate\Foundation\Http\Kernel as HttpKernel;

class Kernel extends HttpKernel
{
    protected $middleware = [
        \App\Http\Middleware\Cors::class,
        \Illuminate\Http\Middleware\HandleCors::class,
        \Illuminate\Foundation\Http\Middleware\ValidatePostSize::class,
        \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
        \Illuminate\Session\Middleware\StartSession::class,
        \Illuminate\View\Middleware\ShareErrorsFromSession::class,
        \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class,
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ];

    protected $middlewareGroups = [
        'web' => [
            \Illuminate\Cookie\Middleware\EncryptCookies::class,
            \Illuminate\Session\Middleware\StartSession::class,
            \Illuminate\View\Middleware\ShareErrorsFromSession::class,
            \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class,
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ],

        'api' => [
            \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
            'throttle:api',
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
        ],
    ];

    protected $routeMiddleware = [
        'auth' => \App\Http\Middleware\Authenticate::class,
        'auth.basic' => \Illuminate\Auth\Middleware\AuthenticateWithBasicAuth::class,
        'auth.session' => \Illuminate\Session\Middleware\AuthenticateSession::class,
        'cache.headers' => \Illuminate\Http\Middleware\SetCacheHeaders::class,
        'can' => \Illuminate\Auth\Middleware\Authorize::class,
        'guest' => \App\Http\Middleware\RedirectIfAuthenticated::class,
        'password.confirm' => \Illuminate\Auth\Middleware\RequirePassword::class,
        'signed' => \Illuminate\Routing\Middleware\ValidateSignature::class,
        'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
        'verified' => \Illuminate\Auth\Middleware\EnsureEmailIsVerified::class,
    ];
}
EOF

# Создаем базу данных
RUN mkdir -p database && touch database/database.sqlite

# Генерируем ключ и запускаем миграции
RUN php artisan key:generate --force
RUN php artisan migrate --force

# Очищаем кэш
RUN php artisan config:clear
RUN php artisan cache:clear
RUN php artisan route:clear

# Используем порт 3000 чтобы обойти возможные конфликты с Caddy
EXPOSE 3000

# Запускаем на порту 3000
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=3000"]