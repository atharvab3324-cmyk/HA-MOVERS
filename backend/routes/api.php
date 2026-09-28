<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json([
        'success' => true,
        'message' => 'HA Movers API is running',
    ]);
});

Route::post('/auth/register', [AuthController::class, 'register']);