import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart'; // Import untuk groupBy

// --- KONFIGURASI ---
const String host = kIsWeb ? '127.0.0.1' : '10.0.2.2';
const String baseUrl = 'http://$host:8000';

// --- MODEL-MODEL DATA ---
class User {
  final int id;
  final String name;
  final String email;
  final String? profilePhotoUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhotoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? photoUrl;
    if (json['profile_photo_path'] != null) {
      photoUrl = '$baseUrl/storage/${json['profile_photo_path']}';
    }
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      profilePhotoUrl: photoUrl,
    );
  }
}

class ProductImage {
  final int id;
  final String imageUrl;

  ProductImage({required this.id, required this.imageUrl});

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'],
      imageUrl: '$baseUrl/storage/${json['image']}',
    );
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String? category;
  final List<ProductImage> images;
  final List<String> warna;
  final List<String> penyimpanan;

  String? get firstImageUrl => images.isNotEmpty ? images.first.imageUrl : null;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.category,
    required this.images,
    required this.warna,
    required this.penyimpanan,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parseJsonArray(dynamic data) {
      if (data is List) return data.map((item) => item.toString()).toList();
      if (data is String) {
        return data
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    List<ProductImage> parseImages(dynamic data) {
      if (data is List) {
        return data
            .map((imageData) => ProductImage.fromJson(imageData))
            .toList();
      }
      return [];
    }

    return Product(
      id: json['id'],
      name: json['name'] ?? 'No Name',
      description: json['description'] ?? 'No Description',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      category: json['category'],
      images: parseImages(json['images']),
      warna: parseJsonArray(json['warna']),
      penyimpanan: parseJsonArray(json['penyimpanan']),
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class OrderItem {
  final int id;
  final int quantity;
  final double price;
  final Product? product;

  OrderItem({
    required this.id,
    required this.quantity,
    required this.price,
    required this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
    );
  }
}

class Order {
  final int id;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsFromJson = json['items'] as List;
    List<OrderItem> itemList =
        itemsFromJson.map((item) => OrderItem.fromJson(item)).toList();
    return Order(
      id: json['id'],
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      items: itemList,
    );
  }
}

// --- STATE MANAGEMENT ---
class AuthProvider with ChangeNotifier {
  String? _token;
  User? _user;
  String? _uploadError;
  String _authError = '';

  String? get token => _token;
  User? get user => _user;
  String? get uploadError => _uploadError;
  String get authError => _authError;
  bool get isLoggedIn => _token != null;

  void _clearAuthError() {
    _authError = '';
  }

  void _clearUploadError() {
    _uploadError = null;
  }

  Future<void> _processAuthResponse(Map<String, dynamic> responseData) async {
    _user = User.fromJson(responseData['user']);
    await _saveToken(responseData['access_token']);
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _clearAuthError();
    final url = Uri.parse('$baseUrl/api/login');
    try {
      final response = await http.post(
        url,
        body: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        await _processAuthResponse(json.decode(response.body));
        return true;
      } else {
        _authError = "Login Gagal! Periksa kembali email dan password Anda.";
        return false;
      }
    } catch (e) {
      _authError = "Gagal terhubung ke server. Periksa koneksi Anda.";
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    _clearAuthError();
    final url = Uri.parse('$baseUrl/api/register');
    try {
      final response = await http.post(
        url,
        body: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        await _processAuthResponse(responseData);
        return true;
      } else {
        if (responseData['errors'] != null) {
          _authError = responseData['errors'].values.first[0];
        } else {
          _authError =
              responseData['message'] ?? 'Terjadi kesalahan tidak diketahui.';
        }
        return false;
      }
    } catch (e) {
      _authError = "Gagal terhubung ke server. Periksa koneksi Anda.";
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('auth_token')) return;
    _token = prefs.getString('auth_token');
    if (_token != null) {
      final url = Uri.parse('$baseUrl/api/user');
      try {
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (response.statusCode == 200) {
          _user = User.fromJson(json.decode(response.body));
        } else {
          await logout();
        }
      } catch (e) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<bool> updateProfilePicture(File imageFile) async {
    _clearUploadError();
    if (_token == null) {
      _uploadError = "Anda tidak terautentikasi.";
      return false;
    }

    final url = Uri.parse('$baseUrl/api/user/photo');
    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_token'
        ..headers['Accept'] = 'application/json'
        ..files.add(await http.MultipartFile.fromPath('photo', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        await tryAutoLogin();
        return true;
      } else {
        try {
          final decodedBody = json.decode(responseBody);
          _uploadError =
              decodedBody['message'] ?? 'Terjadi kesalahan dari server.';
        } catch (e) {
          _uploadError =
              'Gagal memproses respons server. Status: ${response.statusCode}';
        }
        return false;
      }
    } catch (e) {
      _uploadError = 'Gagal terhubung ke server. Periksa koneksi Anda.';
      return false;
    }
  }
}

class Cart with ChangeNotifier {
  Map<int, CartItem> _items = {};
  final String? authToken;
  Cart(this.authToken, this._items);

  Map<int, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  double get totalPrice {
    var total = 0.0;
    _items.forEach(
      (key, cartItem) => total += cartItem.product.price * cartItem.quantity,
    );
    return total;
  }

  Future<void> fetchCart() async {
    if (authToken == null) return;
    final url = Uri.parse('$baseUrl/api/cart');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final Map<int, CartItem> loadedItems = {};
        for (var itemData in responseData) {
          if (itemData['product'] != null) {
            loadedItems.putIfAbsent(
              itemData['product']['id'],
              () => CartItem(
                product: Product.fromJson(itemData['product']),
                quantity: itemData['quantity'],
              ),
            );
          }
        }
        _items = loadedItems;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching cart: $e");
    }
  }

  Future<void> add(Product product) async {
    if (authToken == null) return;
    final url = Uri.parse('$baseUrl/api/cart');
    final existingItem = _items[product.id];
    try {
      if (existingItem != null) {
        await updateQuantity(product.id, existingItem.quantity + 1);
      } else {
        await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'product_id': product.id, 'quantity': 1}),
        );
        await fetchCart();
      }
    } catch (e) {
      print("Error adding to cart: $e");
    }
  }

  Future<void> updateQuantity(int productId, int quantity) async {
    if (authToken == null) return;
    if (quantity > 0) {
      final url = Uri.parse('$baseUrl/api/cart/item/$productId');
      try {
        await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({'quantity': quantity}),
        );
        await fetchCart();
      } catch (e) {
        print("Error updating quantity: $e");
      }
    } else {
      await removeItem(productId);
    }
  }

  Future<void> removeItem(int productId) async {
    if (authToken == null) return;
    final url = Uri.parse('$baseUrl/api/cart/item/$productId');
    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 200) {
        _items.remove(productId);
        notifyListeners();
      }
    } catch (e) {
      print("Error removing item: $e");
    }
  }

  Future<bool> checkout() async {
    if (authToken == null || _items.isEmpty) return false;
    final url = Uri.parse('$baseUrl/api/checkout');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (response.statusCode == 201) {
        _items.clear();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print("Error checkout: $e");
      return false;
    }
  }

  void clearLocalCart() {
    _items = {};
    notifyListeners();
  }
}

// --- UI WIDGETS ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, Cart>(
          create: (_) => Cart(null, {}),
          update: (ctx, auth, previousCart) =>
              Cart(auth.token, previousCart == null ? {} : previousCart.items),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toko Kami',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Merriweather',
      ),
      home: const HomePage(),
      routes: {
        '/cart': (context) => const CartPage(),
        '/orders': (context) => const OrderHistoryPage(),
        '/profile': (context) => const ProfilePage(),
        '/edit-profile': (context) => const EditProfilePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<AuthProvider>(context, listen: false).tryAutoLogin(),
      builder: (ctx, authResultSnapshot) {
        if (authResultSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            if (auth.isLoggedIn) {
              Provider.of<Cart>(context, listen: false).fetchCart();
              return const MainPage();
            } else {
              return const LoginPage();
            }
          },
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static final List<Widget> _pages = <Widget>[
    ProductListPage(),
    OrderHistoryPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Indeks untuk ikon keranjang
      Navigator.pushNamed(context, '/cart');
    } else if (index == 3) {
      // Indeks untuk ikon profil
      setState(() {
        _selectedIndex = 2; // Ganti ke halaman ProfilePage (indeks 2 di _pages)
      });
    } else {
      setState(() {
        _selectedIndex = index; // Untuk Home dan Orders
      });
    }
  }

  void _navigateToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    int bottomNavIndex;
    // Logika untuk memastikan ikon yang benar di-highlight
    if (_selectedIndex == 2) {
      // Jika halaman Profile aktif
      bottomNavIndex = 3; // Highlight ikon Profile
    } else {
      bottomNavIndex = _selectedIndex; // Selain itu, highlight sesuai indeks
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(onSelectItem: _navigateToPage),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomNavIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 5,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// --- HALAMAN UTAMA / TOKO (UI BARU) ---
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late Future<List<Product>> _productsFuture;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  final List<String> _categories = const [
    'Semua',
    'Laptop',
    'Smartphone',
    'Jam',
  ];

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        final products =
            body.map((dynamic item) => Product.fromJson(item)).toList();

        if (mounted) {
          setState(() {
            _allProducts = products;
            _filterProducts();
          });
        }
        return products;
      } else {
        throw Exception('Gagal memuat produk. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final categoryMatch = _selectedCategory == 'Semua' ||
            (product.category?.toLowerCase() ==
                _selectedCategory.toLowerCase());

        final queryMatch =
            query.isEmpty || product.name.toLowerCase().contains(query);

        return categoryMatch && queryMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: const Color(0xFFF8F9FA),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              title: const Text(
                'Toko Kami',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined,
                      color: Colors.black),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined,
                      color: Colors.black),
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                ),
                const SizedBox(width: 8)
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: user?.profilePhotoUrl != null
                              ? NetworkImage(user!.profilePhotoUrl!)
                              : null,
                          child: user?.profilePhotoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Halo, ${user?.name ?? 'Guest'}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Search Filter',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF8A65),
                            Color(0xFFBA68C8),
                            Color(0xFF7986CB),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Soost Search',
                              prefixIcon:
                                  Icon(Icons.mic_none, color: Colors.grey),
                              suffixIcon:
                                  Icon(Icons.search, color: Colors.grey),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: CategoryFilter(
                categories: _categories,
                selectedCategory: _selectedCategory,
                onCategorySelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                    _filterProducts();
                  });
                },
              ),
            ),
            SliverToBoxAdapter(
              child: PopularProductsCarousel(
                products: _allProducts.take(5).toList(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    );
                  }
                  if (_filteredProducts.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(child: Text('Produk tidak ditemukan.')),
                    );
                  }
                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          ProductCard(product: _filteredProducts[index]),
                      childCount: _filteredProducts.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopularProductsCarousel extends StatefulWidget {
  final List<Product> products;
  const PopularProductsCarousel({Key? key, required this.products})
      : super(key: key);

  @override
  State<PopularProductsCarousel> createState() =>
      _PopularProductsCarouselState();
}

class _PopularProductsCarouselState extends State<PopularProductsCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Produk Populer',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.products.length,
            itemBuilder: (context, index) {
              return _PopularProductCard(product: widget.products[index]);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.products.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? Colors.deepPurple
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopularProductCard extends StatelessWidget {
  final Product product;
  const _PopularProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              product.firstImageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(color: Colors.grey),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.blue.withOpacity(0.8),
                    Colors.purple.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'PRODUK LARIS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Koleksi premium kami',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ProductDetailPage(product: product),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.8),
                              Colors.lightBlue.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          child: const Text(
                            'Explore',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final Map<String, IconData> _categoryIcons = const {
    'Semua': Icons.widgets_rounded,
    'Laptop': Icons.laptop_mac_rounded,
    'Smartphone': Icons.phone_iphone_rounded,
    'Jam': Icons.watch_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () => onCategorySelected(category),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0),
                      color: isSelected
                          ? Colors.grey.shade300
                          : Colors.grey.shade100,
                      border: Border.all(
                        color:
                            isSelected ? Colors.black87 : Colors.grey.shade300,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Icon(
                      _categoryIcons[category] ?? Icons.category,
                      color: isSelected ? Colors.black : Colors.black54,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.black54,
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailPage(product: product),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: product.firstImageUrl != null
                    ? Image.network(
                        product.firstImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          );
                        },
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            formatCurrency.format(product.price),
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

// --- SISA HALAMAN LAINNYA ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success = await auth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.authError), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Masukkan email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Password tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Login'),
                      ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const RegisterPage()),
                  ),
                  child: const Text('Belum punya akun? Daftar di sini'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success = await auth.register(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
      _passwordConfirmController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.authError), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Baru')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Nama tidak boleh kosong'
                      : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Masukkan email yang valid';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Password minimal 8 karakter'
                      : null,
                ),
                TextFormField(
                  controller: _passwordConfirmController,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password',
                  ),
                  obscureText: true,
                  validator: (value) => value != _passwordController.text
                      ? 'Password tidak cocok'
                      : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Daftar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Future<void> _buyNow() async {
    int quantity = 1;
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Beli Langsung'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('Jumlah:'),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: quantity > 1
                      ? () => setDialogState(() => quantity--)
                      : null,
                ),
                Text(quantity.toString(), style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setDialogState(() => quantity++),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(ctx).pop(null),
              ),
              ElevatedButton(
                child: const Text('Konfirmasi'),
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  if (auth.token == null) {
                    Navigator.of(ctx).pop(false);
                    return;
                  }
                  final url = Uri.parse('$baseUrl/api/checkout/now');
                  try {
                    final response = await http.post(
                      url,
                      headers: {
                        'Authorization': 'Bearer ${auth.token}',
                        'Content-Type': 'application/json',
                      },
                      body: json.encode({
                        'product_id': widget.product.id,
                        'quantity': quantity,
                      }),
                    );
                    Navigator.of(ctx).pop(response.statusCode == 201);
                  } catch (e) {
                    Navigator.of(ctx).pop(false);
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (success == true && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pesanan Berhasil'),
          content: const Text('Pesanan Anda telah berhasil dibuat.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacementNamed('/orders');
              },
              child: const Text('Lihat Pesanan'),
            ),
          ],
        ),
      );
    } else if (success == false && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuat pesanan.')));
    }
  }

  Widget _buildOptionsSection(String title, List<String> options) {
    if (options.isEmpty || (options.length == 1 && options.first.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: options
              .map(
                (option) => Chip(
                  label: Text(option),
                  backgroundColor: Colors.teal.shade50,
                  labelStyle: TextStyle(color: Colors.teal.shade800),
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              color: Colors.white,
              child: widget.product.firstImageUrl != null
                  ? Image.network(
                      widget.product.firstImageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        size: 100,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported_outlined,
                      size: 100,
                      color: Colors.grey,
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency.format(widget.product.price),
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  _buildOptionsSection('Pilihan Warna', widget.product.warna),
                  _buildOptionsSection(
                    'Pilihan Penyimpanan',
                    widget.product.penyimpanan,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Deskripsi Produk',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final cart = Provider.of<Cart>(context, listen: false);
                  await cart.add(widget.product);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.product.name} berhasil ditambahkan!',
                        ),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.teal),
                  foregroundColor: Colors.teal,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Icon(Icons.add_shopping_cart),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => _buyNow(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Beli Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isLoading = false;

  void _doCheckout() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<Cart>(context, listen: false).checkout();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Checkout Berhasil!'),
          content: const Text(
            'Pesanan Anda telah kami terima dan sedang diproses.',
          ),
          actions: [
            TextButton(
              child: const Text('Tutup'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Lihat Pesanan Saya'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/orders');
              },
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout gagal. Keranjang Anda mungkin kosong.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Cart>(
      builder: (context, cart, child) {
        final formatCurrency = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Keranjang'),
            elevation: 0,
            backgroundColor: const Color(0xFFF5F5F5),
            foregroundColor: Colors.black,
          ),
          backgroundColor: const Color(0xFFF5F5F5),
          body: cart.items.isEmpty
              ? const Center(child: Text('Keranjang Anda masih kosong.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items.values.toList()[index];
                    return CartItemCard(
                      cartItem: cartItem,
                      formatCurrency: formatCurrency,
                      onUpdateQuantity: (newQuantity) {
                        cart.updateQuantity(cartItem.product.id, newQuantity);
                      },
                      onRemoveItem: () {
                        cart.removeItem(cartItem.product.id);
                      },
                    );
                  },
                ),
          bottomNavigationBar: cart.items.isEmpty
              ? null
              : _buildCheckoutSection(context, cart, formatCurrency),
        );
      },
    );
  }

  Widget _buildCheckoutSection(
      BuildContext context, Cart cart, NumberFormat formatCurrency) {
    final double shippingCost = 0.0;
    final double total = cart.totalPrice + shippingCost;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              Text(
                formatCurrency.format(cart.totalPrice),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shipping Cost',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              Text(
                formatCurrency.format(shippingCost),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(thickness: 1, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(
                formatCurrency.format(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _doCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text('Checkout'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final NumberFormat formatCurrency;
  final Function(int) onUpdateQuantity;
  final VoidCallback onRemoveItem;

  const CartItemCard({
    Key? key,
    required this.cartItem,
    required this.formatCurrency,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                cartItem.product.firstImageUrl ?? '',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cartItem.product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency.format(cartItem.product.price),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => onUpdateQuantity(cartItem.quantity - 1),
                    ),
                    Text(
                      cartItem.quantity.toString(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => onUpdateQuantity(cartItem.quantity + 1),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.black54),
                  onPressed: onRemoveItem,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- HALAMAN RIWAYAT PESANAN ---
class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});
  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<List<Order>> _ordersFuture;
  List<Order> _allOrders = [];
  Map<String, List<Order>> _groupedOrders = {};

  String _selectedStatus = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchAndGroupOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterOrders);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchAndGroupOrders();
    });
  }

  Future<List<Order>> _fetchAndGroupOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) throw Exception('Not authenticated');
    final url = Uri.parse('$baseUrl/api/orders');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        final orders =
            responseData.map((data) => Order.fromJson(data)).toList();
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (mounted) {
          setState(() {
            _allOrders = orders;
            _filterOrders();
          });
        }
        return orders;
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();

    List<Order> filteredList = _allOrders.where((order) {
      String uiStatus;
      switch (order.status.toLowerCase()) {
        case 'completed':
          uiStatus = 'Selesai';
          break;
        case 'cancelled':
          uiStatus = 'Dibatalkan';
          break;
        default:
          uiStatus = order.status;
      }

      final statusMatch = _selectedStatus == 'Semua' ||
          uiStatus.toLowerCase() == _selectedStatus.toLowerCase();

      final queryMatch = query.isEmpty ||
          order.id.toString().contains(query) ||
          order.items.any(
            (item) => item.product?.name.toLowerCase().contains(query) ?? false,
          );
      return statusMatch && queryMatch;
    }).toList();

    setState(() {
      _groupedOrders = groupBy(
        filteredList,
        (Order order) =>
            DateFormat('MMMM yyyy', 'id_ID').format(order.createdAt),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> statuses = ['Semua', 'Pending', 'Selesai', 'Dibatalkan'];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50.withOpacity(0.5),
              const Color(0xFFF8F9FA),
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Riwayat Pemesanan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Merriweather',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_outlined,
                            size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Filter Filter",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: statuses.length,
                          itemBuilder: (context, index) {
                            final status = statuses[index];
                            final isSelected = _selectedStatus == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10.0),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedStatus = status;
                                      _filterOrders();
                                    });
                                  }
                                },
                                backgroundColor: isSelected
                                    ? Colors.blue.shade100
                                    : Colors.white,
                                selectedColor: Colors.blue.shade100,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.blue.shade800
                                      : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Colors.blue.shade100
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                showCheckmark: false,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<Order>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                          child: Text('Gagal memuat data: ${snapshot.error}')),
                    );
                  } else if (_allOrders.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                          child: Text('Anda belum memiliki pesanan.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey))),
                    );
                  } else if (_groupedOrders.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                          child: Text('Pesanan tidak ditemukan.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey))),
                    );
                  } else {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          String monthYear =
                              _groupedOrders.keys.elementAt(index);
                          List<Order> ordersInGroup =
                              _groupedOrders[monthYear]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 20, 20, 10),
                                child: Text(
                                  "Pesanan $monthYear",
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...ordersInGroup.map((order) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  child: OrderCard(order: order),
                                );
                              }).toList(),
                            ],
                          );
                        },
                        childCount: _groupedOrders.keys.length,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  const OrderCard({super.key, required this.order});

  Widget _buildStatusIndicator(String status) {
    Color color;
    String text;
    switch (status.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        text = 'Selesai';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'cancelled':
        color = Colors.grey;
        text = 'Dibatalkan';
        break;
      default:
        color = Colors.blue;
        text = status;
    }
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildItemCountChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$count items",
        style: TextStyle(
            color: Colors.green.shade800,
            fontSize: 12,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Detail Pesanan #${order.id}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...order.items.map((item) {
                    final productName =
                        item.product?.name ?? '[Produk Dihapus]';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.product?.firstImageUrl ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.image_not_supported),
                        ),
                      ),
                      title: Text(productName),
                      subtitle: Text(
                        '${item.quantity} x ${formatCurrency.format(item.price)}',
                      ),
                    );
                  }).toList(),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pesanan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        formatCurrency.format(order.totalPrice),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.teal),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final formatDate = DateFormat('d MMMM yyyy', 'id_ID');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showOrderDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDate.format(order.createdAt),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#ORD-${order.id}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildItemCountChip(order.items.length),
                      const SizedBox(height: 8),
                      Text(
                        formatCurrency.format(order.totalPrice),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStatusIndicator(order.status),
              const Divider(height: 20),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.product?.firstImageUrl ?? '',
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 45,
                            height: 45,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.updateProfilePicture(_imageFile!);

      if (mounted) {
        final message = authProvider.uploadError ??
            (success
                ? 'Foto profil berhasil diperbarui!'
                : 'Gagal memperbarui foto.');

        setState(() {
          _isUploading = false;
          _imageFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdatePasswordDialog() {
    final passwordFormKey = GlobalKey<FormState>();
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Password'),
        content: Form(
          key: passwordFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password Saat Ini',
                  ),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                ),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: const InputDecoration(labelText: 'Password Baru'),
                  obscureText: true,
                  validator: (v) => v!.length < 8 ? 'Minimal 8 karakter' : null,
                ),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                  ),
                  obscureText: true,
                  validator: (v) => v != _newPasswordController.text
                      ? 'Password tidak cocok'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!passwordFormKey.currentState!.validate()) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final url = Uri.parse('$baseUrl/api/user/password');
              try {
                final response = await http.put(
                  url,
                  headers: {
                    'Authorization': 'Bearer ${auth.token}',
                    'Accept': 'application/json',
                  },
                  body: {
                    'current_password': _currentPasswordController.text,
                    'password': _newPasswordController.text,
                    'password_confirmation': _confirmPasswordController.text,
                  },
                );
                Navigator.of(ctx).pop();
                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password berhasil diubah!')),
                  );
                } else {
                  final error = json.decode(response.body)['message'];
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Gagal: $error')));
                }
              } catch (e) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<AuthProvider>(context, listen: false).logout();
              Provider.of<Cart>(context, listen: false).clearLocalCart();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = auth.user!;

        ImageProvider? backgroundImage;
        if (_imageFile != null) {
          backgroundImage = FileImage(_imageFile!);
        } else if (user.profilePhotoUrl != null) {
          backgroundImage = NetworkImage(user.profilePhotoUrl!);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Profil Saya')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: backgroundImage,
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : (backgroundImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white70,
                                )
                              : null),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal,
                          border: Border.all(width: 2, color: Colors.white),
                        ),
                        child: InkWell(
                          onTap:
                              _isUploading ? null : _showImageSourceActionSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                _buildProfileMenu(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          _ProfileMenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profil',
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
          ),
          _ProfileMenuItem(
            icon: Icons.lock_outline,
            title: 'Ubah Password',
            onTap: _showUpdatePasswordDialog,
          ),
          _ProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Pusat Bantuan',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ini akan segera hadir!')),
              );
            },
          ),
          const Divider(height: 30),
          _ProfileMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            textColor: Colors.red,
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor ?? Colors.teal),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: textColor == null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final url = Uri.parse('$baseUrl/api/user/profile-information');

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text,
          'email': _emailController.text,
        }),
      );

      if (response.statusCode == 200) {
        await auth.tryAutoLogin();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil berhasil diperbarui!')),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Gagal memperbarui profil: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator: (value) =>
                    value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty || !value.contains('@')
                    ? 'Email tidak valid'
                    : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// WIDGET DRAWER BARU
class AppDrawer extends StatelessWidget {
  final Function(int) onSelectItem;
  const AppDrawer({Key? key, required this.onSelectItem}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final user = auth.user;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user?.name ?? 'Guest'),
                accountEmail: Text(user?.email ?? 'Tidak ada email'),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: user?.profilePhotoUrl != null
                      ? NetworkImage(user!.profilePhotoUrl!)
                      : null,
                  child: user?.profilePhotoUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade300,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: const Text('Toko'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectItem(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Riwayat Pesanan'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectItem(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profil'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectItem(2); // Indeks untuk ProfilePage
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red.shade700),
                title: Text('Logout',
                    style: TextStyle(color: Colors.red.shade700)),
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Konfirmasi Logout'),
                      content: const Text('Apakah Anda yakin ingin keluar?'),
                      actions: [
                        TextButton(
                          child: const Text('Batal'),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        TextButton(
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            auth.logout();
                            Provider.of<Cart>(context, listen: false)
                                .clearLocalCart();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
