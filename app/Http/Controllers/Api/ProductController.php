<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    /**
     * Display a listing of the resource.
     * --- SUDAH DIPERBAIKI ---
     */
    public function index()
    {
        // Gunakan `with('images')` untuk mengambil data produk BESERTA gambar-gambarnya
        $products = Product::with('images')->latest()->get();
        return response()->json($products);
    }

    /**
     * Store a newly created resource in storage.
     * (Method ini tidak perlu diubah untuk masalah gambar)
     */
    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'price' => 'required|numeric|min:0',
        ]);

        $product = Product::create($validatedData);

        return response()->json($product, 201);
    }

    /**
     * Display the specified resource.
     * --- SUDAH DIPERBAIKI ---
     */
    public function show($id)
    {
        // Gunakan `with('images')` juga di sini untuk detail produk
        $product = Product::with('images')->findOrFail($id);
        return response()->json($product);
    }

    // ... sisa method (update, destroy) tidak perlu diubah ...
    
    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, $id)
    {
        $product = Product::findOrFail($id);

        $validatedData = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'description' => 'sometimes|required|string',
            'price' => 'sometimes|required|numeric|min:0',
        ]);

        $product->update($validatedData);

        return response()->json($product);
    }

    /**
     * Remove the specified resource from storage.
     */
    public function destroy($id)
    {
        $product = Product::findOrFail($id);
        $product->delete();
        return response()->json(['message' => 'Product successfully deleted.']);
    }
}