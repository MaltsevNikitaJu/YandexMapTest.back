<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Adds the current CSRF token to response headers so SPAs can read it
 * even when the XSRF cookie is HttpOnly or scoped to another domain.
 */
class ExposeCsrfToken
{
    public function handle(Request $request, Closure $next): Response
    {
        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        $token = $request->session()->token();

        if ($token) {
            $response->headers->set('X-XSRF-TOKEN', $token);
        }

        return $response;
    }
}

