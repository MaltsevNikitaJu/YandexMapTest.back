<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\YandexPlace;
use App\Services\Yandex\YandexReviewsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class YandexPlaceController extends Controller
{
    public function index(Request $request)
    {
        $places = $request->user()->yandexPlaces()->get();

        return response()->json($places);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'url' => ['required', 'string', 'max:2048'],
        ]);

        $placeId = $this->extractPlaceIdFromUrl($validated['url']);

        if (! $placeId) {
            return response()->json([
                'message' => 'Не удалось извлечь ID заведения из ссылки',
            ], 422);
        }

        if ($request->user()->yandexPlaces()->where('place_id', $placeId)->exists()) {
            return response()->json([
                'message' => 'Такое заведение уже добавлено',
            ], 422);
        }

        $placeName = $this->fetchPlaceName($validated['url']);

        $place = $request->user()->yandexPlaces()->create([
            'place_id' => $placeId,
            'name' => $placeName,
            'url' => $validated['url'],
        ]);

        return response()->json($place, 201);
    }

    public function destroy(Request $request, int $placeId): JsonResponse
    {
        $deleted = $request->user()
            ->yandexPlaces()
            ->where('id', $placeId)
            ->delete();

        if (! $deleted) {
            return response()->json(['message' => 'Заведение не найдено'], 404);
        }

        return response()->json([
            'message' => 'Заведение удалено',
        ]);
    }

    public function reviews(
        Request $request,
        int $placeId,
        YandexReviewsService $reviewsService
    ): JsonResponse {
        $place = $request->user()
            ->yandexPlaces()
            ->where('id', $placeId)
            ->first();

        if (! $place) {
            return response()->json(['message' => 'Заведение не найдено'], 404);
        }

        try {
            $data = $reviewsService->fetch(
                $place->url,
                min(max((int) $request->integer('limit', 10), 1), 50)
            );
        } catch (\Throwable $e) {
            Log::error('Yandex reviews fetch failed', [
                'place_id' => $place->place_id,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'message' => 'Не удалось получить отзывы с Яндекс.Карт',
            ], 502);
        }

        return response()->json([
            'place' => [
                'id' => $place->id,
                'name' => $place->name,
                'url' => $place->url,
            ],
            'summary' => [
                'rating' => $data['rating'],
                'ratingsCount' => $data['ratingsCount'],
                'reviewsCount' => $data['reviewsCount'],
            ],
            'reviews' => $data['reviews'],
        ]);
    }

    private function extractPlaceIdFromUrl(string $url): ?string
    {
        $path = parse_url($url, PHP_URL_PATH) ?? '';

        // Ищем цифры между /org/.../ID/ в пути
        if (preg_match('#/org/[^/]+/(\d+)#', $path, $matches)) {
            return $matches[1];
        }

        return null;
    }

    private function fetchPlaceName(string $url): ?string
    {
        try {
            $response = Http::withoutVerifying()->get($url);

            if (! $response->successful()) {
                return null;
            }

            $html = $response->body();
            if (! $html) {
                return null;
            }

            libxml_use_internal_errors(true);
            $dom = new \DOMDocument();
            $dom->loadHTML($html);
            $xpath = new \DOMXPath($dom);

            $queries = [
                '//h1[contains(@itemprop,"name")]',
                '//h1[contains(@class,"orgpage-header-view__header")]',
            ];

            foreach ($queries as $query) {
                $node = $xpath->query($query)->item(0);
                $text = $node ? trim($node->textContent) : null;

                if ($text) {
                    return $text;
                }
            }

            return null;
        } catch (\Throwable $e) {
            Log::error('Yandex place name parse failed', [
                'url' => $url,
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }
}


