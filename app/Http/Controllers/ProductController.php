<?php

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProductController extends Controller
{
    /**
     * Menampilkan daftar semua produk dengan gambar utamanya.
     */
    public function index()
    {
        // Eager load relasi 'images' untuk efisiensi query
        $products = Product::with('images')->latest()->get();
        return view('products.index', compact('products'));
    }

    /**
     * Menampilkan form untuk membuat produk baru.
     */
    public function create()
    {
        return view('products.create');
    }

    /**
     * Menyimpan produk baru ke database (SUDAH DIPERBAIKI).
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'price' => 'required|numeric',
            'category' => 'required|string',
            'warna' => 'nullable|string',
            'penyimpanan' => 'nullable|string',
            'images.*' => 'required|image|mimes:jpeg,png,jpg,gif,svg|max:2048' // Validasi untuk multi-gambar
        ]);

        // Fungsi untuk mengubah textarea (satu per baris) menjadi array
        $toArray = function ($value) {
            return array_filter(array_map('trim', explode("\n", $value)));
        };

        try {
            DB::beginTransaction();

            $product = Product::create([
                'name' => $request->name,
                'description' => $request->description,
                'price' => $request->price,
                'category' => $request->category,
                'warna' => $toArray($request->warna),
                'penyimpanan' => $toArray($request->penyimpanan),
            ]);

            if ($request->hasFile('images')) {
                foreach ($request->file('images') as $image) {
                    $path = $image->store('products', 'public');
                    $product->images()->create(['image' => $path]);
                }
            }

            DB::commit();

            return redirect()->route('products.index')
                             ->with('success', 'Produk berhasil ditambahkan.');

        } catch (\Exception $e) {
            DB::rollBack();
            return back()->withInput()->withErrors(['error' => 'Terjadi kesalahan: ' . $e->getMessage()]);
        }
    }

    /**
     * Menampilkan form untuk mengedit produk.
     */
    public function edit(Product $product)
    {
        // Eager load images untuk ditampilkan di form edit
        $product->load('images');
        return view('products.edit', compact('product'));
    }

    /**
     * Mengupdate produk di database (SUDAH DIPERBAIKI).
     */
    public function update(Request $request, Product $product)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'required|string',
            'price' => 'required|numeric',
            'category' => 'required|string',
            'warna' => 'nullable|string',
            'penyimpanan' => 'nullable|string',
            'images.*' => 'nullable|image|mimes:jpeg,png,jpg,gif,svg|max:2048',
        ]);
        
        $toArray = function ($value) {
            return array_filter(array_map('trim', explode("\n", $value)));
        };

        try {
            DB::beginTransaction();
            
            $product->update([
                'name' => $request->name,
                'description' => $request->description,
                'price' => $request->price,
                'category' => $request->category,
                'warna' => $toArray($request->warna),
                'penyimpanan' => $toArray($request->penyimpanan),
            ]);

            if ($request->hasFile('images')) {
                // Hapus gambar lama (opsional, jika Anda ingin mengganti semua)
                // foreach($product->images as $oldImage) {
                //     Storage::disk('public')->delete($oldImage->image);
                //     $oldImage->delete();
                // }

                foreach ($request->file('images') as $image) {
                    $path = $image->store('products', 'public');
                    $product->images()->create(['image' => $path]);
                }
            }

            DB::commit();

            return redirect()->route('products.index')
                             ->with('success', 'Produk berhasil diperbarui.');

        } catch (\Exception $e) {
            DB::rollBack();
            return back()->withInput()->withErrors(['error' => 'Terjadi kesalahan: ' . $e->getMessage()]);
        }
    }

    /**
     * Menghapus produk dari database (SUDAH DIPERBAIKI).
     */
    public function destroy(Product $product)
    {
        try {
            DB::beginTransaction();
            
            // Hapus semua gambar terkait dari storage
            foreach ($product->images as $image) {
                if (Storage::disk('public')->exists($image->image)) {
                    Storage::disk('public')->delete($image->image);
                }
            }
            // Hapus record gambar dari database (otomatis karena onDelete('cascade'))
            
            $product->delete();

            DB::commit();

            return redirect()->route('products.index')
                             ->with('success', 'Produk berhasil dihapus.');
        } catch (\Exception $e) {
            DB::rollBack();
            return back()->withErrors(['error' => 'Gagal menghapus produk: ' . $e->getMessage()]);
        }
    }
}