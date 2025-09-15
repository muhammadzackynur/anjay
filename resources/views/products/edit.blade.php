@extends('layouts.app')

@section('content')
    <h2>Edit Produk</h2>
    <a class="btn btn-primary mb-3" href="{{ route('products.index') }}"> Kembali</a>

    @if ($errors->any())
        <div class="alert alert-danger">
            <strong>Whoops!</strong> Ada beberapa masalah dengan input Anda.<br><br>
            <ul>
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    <form action="{{ route('products.update', $product->id) }}" method="POST" enctype="multipart/form-data">
        @csrf
        @method('PUT')
        <div class="mb-3">
            <label for="name" class="form-label"><strong>Nama:</strong></label>
            <input type="text" name="name" value="{{ $product->name }}" class="form-control">
        </div>
        <div class="mb-3">
            <label for="description" class="form-label"><strong>Deskripsi:</strong></label>
            <textarea class="form-control" style="height:150px" name="description">{{ $product->description }}</textarea>
        </div>
        <div class="mb-3">
            <label for="price" class="form-label"><strong>Harga:</strong></label>
            <input type="number" name="price" value="{{ $product->price }}" class="form-control">
        </div>

        <div class="mb-3">
            <label for="category" class="form-label"><strong>Kategori:</strong></label>
            <select name="category" class="form-select">
                <option disabled>Pilih Kategori</option>
                <option value="Laptop" @if($product->category == 'Laptop') selected @endif>Laptop</option>
                <option value="Smartphone" @if($product->category == 'Smartphone') selected @endif>Smartphone</option>
                <option value="Jam" @if($product->category == 'Jam') selected @endif>Jam</option>
            </select>
        </div>
        
        <div class="mb-3">
            <label for="warna" class="form-label"><strong>Warna:</strong> (Satu warna per baris)</label>
            <textarea name="warna" class="form-control" rows="3">{{ is_array($product->warna) ? implode("\n", $product->warna) : $product->warna }}</textarea>
        </div>
        <div class="mb-3">
            <label for="penyimpanan" class="form-label"><strong>Penyimpanan:</strong> (Satu opsi per baris)</label>
            <textarea name="penyimpanan" class="form-control" rows="3">{{ is_array($product->penyimpanan) ? implode("\n", $product->penyimpanan) : $product->penyimpanan }}</textarea>
        </div>
        
        {{-- === BAGIAN YANG DIPERBAIKI === --}}
        <div class="mb-3">
            <label for="images" class="form-label"><strong>Tambah Gambar Produk:</strong> (Bisa pilih lebih dari satu)</label>
            <input type="file" name="images[]" class="form-control" multiple>
        </div>

        <div class="mb-3">
            <strong>Gambar Saat Ini:</strong>
            <div class="row mt-2">
                @forelse($product->images as $image)
                    <div class="col-md-3">
                        <div class="position-relative">
                            <img src="{{ asset('storage/' . $image->image) }}" alt="{{ $product->name }}" class="img-thumbnail">
                            {{-- Anda bisa menambahkan tombol hapus di sini jika diperlukan --}}
                            {{-- Contoh: <button class="btn btn-danger btn-sm position-absolute top-0 end-0">X</button> --}}
                        </div>
                    </div>
                @empty
                    <div class="col">
                        <p class="text-muted">Tidak ada gambar untuk produk ini.</p>
                    </div>
                @endforelse
            </div>
        </div>
        {{-- ============================== --}}

        <div class="text-center">
            <button type="submit" class="btn btn-success">Update</button>
        </div>
    </form>
@endsection