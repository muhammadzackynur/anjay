@extends('layouts.app')

@section('content')
    <h2>Edit Produk</h2>
    <a class="btn btn-primary mb-3" href="{{ route('products.index') }}"> Kembali</a>

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
            <input type="number" step="0.01" name="price" value="{{ $product->price }}" class="form-control">
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
            <label for="image" class="form-label"><strong>Gambar Produk:</strong></label>
            <input type="file" name="image" class="form-control">
            @if($product->image)
                <img src="{{ asset('storage/' . $product->image) }}" alt="{{ $product->name }}" class="img-thumbnail mt-2" width="150">
            @endif
        </div>
        <div class="text-center">
            <button type="submit" class="btn btn-success">Update</button>
        </div>
    </form>
@endsection