<?php

namespace App\Services\Yandex;

use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class YandexReviewsService
{

    /**
     * @param  string  $placeUrl  Полная ссылка на страницу заведения
     * @return array{
     *     rating: float|null,
     *     ratingsCount: int|null,
     *     reviewsCount: int|null,
     *     reviews: array<int, array{
     *          id: string,
     *          rating: int|null,
     *          text: string,
     *          updatedTime: string|null,
     *          author: array{
     *              name: string,
     *              avatarUrl: string|null,
     *              professionLevel: string|null,
     *          },
     *          businessComment: string|null,
     *     }>
     * }
     */
    public function fetch(string $placeUrl, int $limit = 10): array
    {
        $targetUrl = $this->buildReviewsUrl($placeUrl);

        $response = Http::withoutVerifying()
            ->withHeaders([
                'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
                    .' AppleWebKit/537.36 (KHTML, like Gecko)'
                    .' Chrome/118.0.0.0 Safari/537.36',
                'Accept-Language' => 'ru-RU,ru;q=0.9',
            ])
            ->get($targetUrl);

        if (! $response->successful()) {
            throw new \RuntimeException('Не удалось получить страницу заведения на Яндексе');
        }

        $html = $response->body();
        $reviewsJson = $this->extractJsonSection($html, '"reviewResults":');
        $ratingJson = $this->extractJsonSection($html, '"ratingData":');

        if (! $reviewsJson) {
            throw new \RuntimeException('На странице Яндекса не удалось найти блок с отзывами');
        }

        $reviewsData = json_decode($reviewsJson, true, flags: JSON_THROW_ON_ERROR);
        $ratingData = $ratingJson ? json_decode($ratingJson, true, flags: JSON_THROW_ON_ERROR) : [];

        $reviews = collect(Arr::get($reviewsData, 'reviews', []))
            ->take($limit)
            ->map(function ($review): array {
                $author = Arr::get($review, 'author', []);

                return [
                    'id' => Arr::get($review, 'reviewId'),
                    'rating' => Arr::get($review, 'rating'),
                    'text' => trim((string) Arr::get($review, 'text', '')),
                    'updatedTime' => Arr::get($review, 'updatedTime'),
                    'author' => [
                        'name' => Arr::get($author, 'name', 'Гость'),
                        'avatarUrl' => Arr::get($author, 'avatarUrl'),
                        'professionLevel' => Arr::get($author, 'professionLevel'),
                    ],
                    'businessComment' => Arr::get($review, 'businessComment.text'),
                ];
            })
            ->values()
            ->all();

        return [
            'rating' => Arr::get($ratingData, 'ratingValue'),
            'ratingsCount' => Arr::get($ratingData, 'ratingCount'),
            'reviewsCount' => Arr::get($reviewsData, 'params.count'),
            'reviews' => $reviews,
        ];
    }

    private function buildReviewsUrl(string $originalUrl): string
    {
        $urlParts = parse_url($originalUrl);

        $base = ($urlParts['scheme'] ?? 'https').'://'
              .($urlParts['host'] ?? 'yandex.ru')
              .($urlParts['path'] ?? '');

        $query = $urlParts['query'] ?? '';
        parse_str($query, $params);

        // Просим вкладку с отзывами; fallback для старых ссылок.
        $params['tab'] = $params['tab'] ?? 'reviews';
        $params['mode'] = $params['mode'] ?? 'poi';

        return $base.'?'.http_build_query($params);
    }

    private function extractJsonSection(string $html, string $needle): ?string
    {
        $start = strpos($html, $needle);
        if ($start === false) {
            return null;
        }

        $start = strpos($html, '{', $start);
        if ($start === false) {
            return null;
        }

        $depth = 0;
        $length = strlen($html);

        for ($i = $start; $i < $length; $i++) {
            $char = $html[$i];

            if ($char === '{') {
                $depth++;
            } elseif ($char === '}') {
                $depth--;

                if ($depth === 0) {
                    return substr($html, $start, $i - $start + 1);
                }
            }
        }

        return null;
    }
}

