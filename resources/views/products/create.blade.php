@extends('layouts.app')

@section('content')
    <h2>Tambah Produk Baru</h2>
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

    <form action="{{ route('products.store') }}" method="POST" enctype="multipart/form-data">
        @csrf
        <div class="mb-3">
            <label for="name" class="form-label"><strong>Nama:</strong></label>
            <input type="text" name="name" class="form-control" placeholder="Nama Produk" value="{{ old('name') }}">
        </div>
        <div class="mb-3">
            <label for="description" class="form-label"><strong>Deskripsi:</strong></label>
            <textarea class="form-control" style="height:150px" name="description" placeholder="Deskripsi">{{ old('description') }}</textarea>
        </div>
        <div class="mb-3">
            <label for="price" class="form-label"><strong>Harga:</strong></label>
            <input type="number" name="price" class="form-control" placeholder="Harga" value="{{ old('price') }}">
        </div>
        
        <div class="mb-3">
            <label for="category" class="form-label"><strong>Kategori:</strong></label>
            <select name="category" class="form-select">
                <option selected disabled>Pilih Kategori</option>
                <option value="Laptop" @if(old('category') == 'Laptop') selected @endif>Laptop</option>
                <option value="Smartphone" @if(old('category') == 'Smartphone') selected @endif>Smartphone</option>
                <option value="Jam" @if(old('category') == 'Jam') selected @endif>Jam</option>
            </select>
        </div>
        
        <div class="mb-3">
            <label for="warna" class="form-label"><strong>Warna:</strong> (Satu warna per baris)</label>
            <textarea name="warna" class="form-control" rows="3" placeholder="Contoh:&#10;Hitam&#10;Putih&#10;Silver">{{ old('warna') }}</textarea>
        </div>
        <div class="mb-3">
            <label for="penyimpanan" class="form-label"><strong>Penyimpanan:</strong> (Satu opsi per baris)</label>
            <textarea name="penyimpanan" class="form-control" rows="3" placeholder="Contoh:&#10;256GB&#10;512GB&#10;1TB">{{ old('penyimpanan') }}</textarea>
        </div>
        
        {{-- === BAGIAN YANG DIPERBAIKI === --}}
        <div class="mb-3">
            <label for="images" class="form-label"><strong>Gambar Produk:</strong> (Bisa pilih lebih dari satu)</label>
            <input type="file" name="images[]" class="form-control" multiple>
        </div>
        {{-- ============================== --}}
        
        <div class="text-center">
            <button type="submit" class="btn btn-success">Simpan</button>
        </div>
    </form>
@endsection