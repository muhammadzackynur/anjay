<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('products', function (Blueprint $table) {
            // TAMBAHKAN DUA BARIS INI
            $table->string('warna')->nullable()->after('category');
            $table->string('penyimpanan')->nullable()->after('warna');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('products', function (Blueprint $table) {
            // TAMBAHKAN BARIS INI UNTUK ROLLBACK
            $table->dropColumn(['warna', 'penyimpanan']);
        });
    }
};