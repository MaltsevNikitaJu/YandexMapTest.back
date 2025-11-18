<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('yandex_places', function (Blueprint $table): void {
            $table->string('name')->nullable()->after('place_id');
        });
    }

    public function down(): void
    {
        Schema::table('yandex_places', function (Blueprint $table): void {
            $table->dropColumn('name');
        });
    }
};


