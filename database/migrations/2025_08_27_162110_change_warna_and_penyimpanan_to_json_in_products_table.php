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
            // Mengubah tipe kolom menjadi JSON
            $table->json('warna')->nullable()->change();
            $table->json('penyimpanan')->nullable()->change();
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
            // Mengembalikan tipe kolom menjadi string jika di-rollback
            $table->string('warna')->nullable()->change();
            $table->string('penyimpanan')->nullable()->change();
        });
    }
};