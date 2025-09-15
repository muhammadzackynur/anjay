@extends('layouts.app')

@section('content')
<div class="container mt-5">
    <div class="row">
        <div class="col-md-12">
            <div class="card border-0 shadow-sm rounded">
                <div class="card-body">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h3 class="my-0">Manajemen Produk</h3>
                        <a href="{{ route('products.create') }}" class="btn btn-success">Tambah Produk Baru</a>
                    </div>

                    @if (session('success'))
                        <div class="alert alert-success">
                            {{ session('success') }}
                        </div>
                    @endif
                    
                    @if ($errors->any())
                        <div class="alert alert-danger">
                            <ul class="mb-0">
                                @foreach ($errors->all() as $error)
                                    <li>{{ $error }}</li>
                                @endforeach
                            </ul>
                        </div>
                    @endif

                    <table class="table table-bordered table-striped">
                        <thead class="table-dark">
                            <tr>
                                <th scope="col">No</th>
                                <th scope="col">Gambar</th>
                                <th scope="col">Nama</th>
                                <th scope="col" style="text-align: right;">Harga</th>
                                <th scope="col">Kategori</th>
                                <th scope="col">Warna</th>
                                <th scope="col">Penyimpanan</th>
                                <th scope="col" width="180px">Aksi</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($products as $product)
                            <tr>
                                <td>{{ $loop->iteration }}</td>
                                <td>
                                    @if($product->images->isNotEmpty())
                                        <img src="{{ asset('storage/' . $product->images->first()->image) }}" alt="{{ $product->name }}" class="img-thumbnail" width="100">
                                    @else
                                        <div class="d-flex justify-content-center align-items-center bg-light" style="width: 100px; height: 100px;">
                                            <span class="text-muted small">No Image</span>
                                        </div>
                                    @endif
                                </td>
                                <td>{{ $product->name }}</td>
                                <td style="text-align: right;">Rp {{ number_format($product->price, 0, ',', '.') }}</td>
                                <td><span class="badge bg-primary">{{ $product->category }}</span></td>
                                
                                {{-- ================== BAGIAN YANG DIPERBAIKI ================== --}}
                                <td>
                                    {{-- Cek dulu apakah $product->warna adalah array --}}
                                    @if(is_array($product->warna))
                                        @forelse($product->warna as $item_warna)
                                            <span class="badge bg-secondary mb-1">{{ $item_warna }}</span>
                                        @empty
                                            -
                                        @endforelse
                                    @else
                                        {{-- Jika bukan array (data lama), tampilkan sebagai teks biasa --}}
                                        {{ $product->warna ?? '-' }}
                                    @endif
                                </td>
                                <td>
                                    {{-- Cek dulu apakah $product->penyimpanan adalah array --}}
                                    @if(is_array($product->penyimpanan))
                                        @forelse($product->penyimpanan as $item_penyimpanan)
                                            <span class="badge bg-dark mb-1">{{ $item_penyimpanan }}</span>
                                        @empty
                                            -
                                        @endforelse
                                    @else
                                        {{-- Jika bukan array (data lama), tampilkan sebagai teks biasa --}}
                                        {{ $product->penyimpanan ?? '-' }}
                                    @endif
                                </td>
                                {{-- ============================================================= --}}

                                <td class="text-center">
                                    <form action="{{ route('products.destroy', $product->id) }}" method="POST" onsubmit="return confirm('Apakah Anda yakin ingin menghapus produk ini?');">
                                        <a class="btn btn-primary btn-sm" href="{{ route('products.edit', $product->id) }}">Edit</a>
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-danger btn-sm">Hapus</button>
                                    </form>
                                </td>
                            </tr>
                            @empty
                            <tr>
                                <td colspan="8" class="text-center">
                                    <div class="alert alert-info my-3">
                                        Belum ada produk. Silakan tambahkan produk baru.
                                    </div>
                                </td>
                            </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection