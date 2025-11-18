<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\YandexPlaceController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function (): void {
    Route::get('/user', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::patch('/user', [ProfileController::class, 'update']);
    Route::post('/user/password', [ProfileController::class, 'updatePassword']);

    Route::get('/yandex-places', [YandexPlaceController::class, 'index']);
    Route::post('/yandex-places', [YandexPlaceController::class, 'store']);
    Route::delete('/yandex-places/{placeId}', [YandexPlaceController::class, 'destroy']);
    Route::get('/yandex-places/{placeId}/reviews', [YandexPlaceController::class, 'reviews']);
});
