import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import 'catalog_support.dart';
import 'my_products_screen.dart';
import 'product_details_screen.dart';

class HomeScreenTwo extends StatefulWidget {
  const HomeScreenTwo({super.key});

  @override
  State<HomeScreenTwo> createState() => _HomeScreenTwoState();
}

class _HomeScreenTwoState extends State<HomeScreenTwo>
    with CatalogState<HomeScreenTwo> {
  int _currentBottomIndex = 0;
  int _bannerIndex = 0;

  final PageController _bannerController = PageController();
  final ScrollController _categoryScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _bannerTimer;
  Timer? _categoryTimer;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  String? _profileUid;
  String _userName = '';
  String _userInitials = '';
  bool _openingProductForm = false;

  String _catalogSearch = '';
  String? _catalogCategory;

  String _text(dynamic value) => (value ?? '').toString();

  List<Map<String, String>> get _categories => [
    {'name': 'All', 'icon': 'category'},
    ...catalogCategories.map((name) => {'name': name, 'icon': 'category'}),
  ];

  List<Map<String, dynamic>> get _visibleProducts {
    final search = _catalogSearch.trim().toLowerCase();

    return catalogProducts.where((product) {
      final searchableText =
          '${product['productName'] ?? ''} '
                  '${product['category'] ?? ''} '
                  '${product['sellerShopName'] ?? ''} '
                  '${product['id'] ?? ''}'
              .toLowerCase();

      return product['isActive'] == true &&
          product['status'] == 'Approved' &&
          (_catalogCategory == null ||
              product['category'] == _catalogCategory) &&
          searchableText.contains(search);
    }).toList();
  }

  final List<Map<String, String>> _banners = const [
    {
      'subtitle': 'Best Quality Products',
      'title': 'For Your Business',
      'desc': 'Huge Range | Best Prices | Fast Delivery',
      'btn': 'Shop Now',
    },
    {
      'subtitle': 'Exclusive Discount',
      'title': 'Up to 30% Off Electricals',
      'desc': 'Top Brands | Certified Safety | Wholesale Prices',
      'btn': 'Explore Offer',
    },
    {
      'subtitle': 'New Arrivals',
      'title': 'Premium Lighting & Fixtures',
      'desc': 'Modern Designs | Energy Efficient | Durable Build',
      'btn': 'View Collection',
    },
  ];

  @override
  void initState() {
    super.initState();
    _watchUserProfile();
    _startBannerAutoSlider();
    _startCategoryAutoSlider();
  }

  void _watchUserProfile() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        _profileSubscription?.cancel();
        _profileSubscription = null;

        if (!mounted) return;

        setState(() {
          _profileUid = user?.uid;
          _userName = '';
          _userInitials = '';
        });

        if (user == null) return;

        final uid = user.uid;

        _profileSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots()
            .listen(
              (snapshot) {
                if (!mounted || _profileUid != uid) return;

                final profile = snapshot.data();
                final firstName = _text(profile?['firstName']).trim();
                final lastName = _text(profile?['lastName']).trim();

                final nameParts = [
                  firstName,
                  lastName,
                ].where((part) => part.isNotEmpty).toList();

                final initials = nameParts
                    .map((part) => String.fromCharCode(part.runes.first))
                    .join()
                    .toUpperCase();

                setState(() {
                  _userName = nameParts.join(' ');
                  _userInitials = initials;
                });
              },
              onError: (Object error) {
                if (!mounted || _profileUid != uid) return;

                setState(() {
                  _userName = '';
                  _userInitials = '';
                });
              },
            );
      },
      onError: (Object error) {
        _profileSubscription?.cancel();
        _profileSubscription = null;

        if (!mounted) return;

        setState(() {
          _profileUid = null;
          _userName = '';
          _userInitials = '';
        });
      },
    );
  }

  void _startBannerAutoSlider() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted ||
          !(ModalRoute.of(context)?.isCurrent ?? false) ||
          !_bannerController.hasClients ||
          _bannerController.position.isScrollingNotifier.value) {
        return;
      }

      final nextIndex = (_bannerIndex + 1) % _banners.length;

      _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _startCategoryAutoSlider() {
    _categoryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted ||
          !(ModalRoute.of(context)?.isCurrent ?? false) ||
          !_categoryScrollController.hasClients ||
          _categoryScrollController.position.isScrollingNotifier.value) {
        return;
      }

      final maxScroll = _categoryScrollController.position.maxScrollExtent;

      if (maxScroll <= 0) return;

      final currentScroll = _categoryScrollController.offset;

      final targetScroll = currentScroll >= maxScroll - 1
          ? 0.0
          : (currentScroll + 80.0).clamp(0.0, maxScroll).toDouble();

      _categoryScrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _openAddProductsForm() async {
    if (_openingProductForm) return;

    const link = 'https://forms.gle/Kj81xvtAtnQuro9s9';
    final uri = Uri.parse(link);

    setState(() => _openingProductForm = true);

    try {
      bool opened = false;

      try {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        opened = false;
      }

      if (!opened) {
        try {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          opened = false;
        }
      }

      if (!mounted || opened) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Open Add Products form'),
          content: const SelectableText(
            'The form could not open automatically. '
            'Copy this link and paste it into Chrome:\n\n$link',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: link));

                if (!mounted) return;
                _showMessage('Link copied. Paste it into Chrome.');
              },
              child: const Text('Copy link'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingProductForm = false);
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _categoryTimer?.cancel();
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _bannerController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyProductsScreen()),
      );
    } else {
      setState(() {
        _currentBottomIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    final visibleProducts = _visibleProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF0052FF),
                      child: _userInitials.isEmpty
                          ? const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                            )
                          : Text(
                              _userInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName.isEmpty ? 'Hi!' : 'Hi, $_userName!',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Welcome to Cart & Order',
                            style: TextStyle(fontSize: 8, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openingProductForm
                          ? null
                          : _openAddProductsForm,
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFF0052FF),
                      ),
                      label: Text(
                        _openingProductForm ? 'Opening…' : 'Add Products',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0052FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        side: const BorderSide(color: Color(0xFF0052FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _catalogSearch = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search Your Products',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (value) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyProductsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Categories
              SizedBox(
                height: 90,
                child: ListView.builder(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final item = categories[index];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _catalogCategory = item['name'] == 'All'
                              ? null
                              : item['name'];
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEBF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(item['icon']!),
                                color: const Color(0xFF0052FF),
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name']!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Banner Carousel
              Column(
                children: [
                  SizedBox(
                    height: 170,
                    child: PageView.builder(
                      controller: _bannerController,
                      itemCount: _banners.length,
                      onPageChanged: (index) {
                        setState(() => _bannerIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final banner = _banners[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0052FF), Color(0xFF0030B8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  banner['subtitle']!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner['title']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner['desc']!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _banners.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _bannerIndex == index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _bannerIndex == index
                              ? const Color(0xFF0052FF)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Product List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (catalogLoading ||
                        catalogFailure != null ||
                        categoryFailure != null)
                      catalogNotice(),
                    if (!catalogLoading &&
                        catalogFailure == null &&
                        visibleProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No products found.'),
                      ),
                    ...visibleProducts.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProductCard(
                          productId: _text(product['id']),
                          imageUrl: _text(product['frontImage']),
                          title: _text(product['productName']),
                          price: _text(product['sellingPrice']),
                          unit: _text(product['unitTypes']),
                          specs: {
                            'Category:': _text(product['category']),
                            'Min quantity:': _text(product['minOrderQuantity']),
                            'Seller:': _text(product['sellerShopName']),
                            'Stock:': _text(product['stockStatus']),
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomIndex,
        selectedItemColor: const Color(0xFF0052FF),
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.visibility_outlined),
                Positioned(
                  right: -6,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0052FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '•',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            label: 'My Products',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String productId,
    required String imageUrl,
    required String title,
    required String price,
    required String unit,
    required Map<String, String> specs,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: catalogImage(imageUrl, width: 100, height: 100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0052FF),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.favorite_border,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        text: price,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(
                            text: ' $unit',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...specs.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: entry.value == 'Out of Stock'
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductDetailsScreen(productId: productId),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Color(0xFF0052FF),
                  ),
                  label: const Text(
                    'View Product',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0052FF)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0052FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Send Enquiry',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'This function is not for sellers.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String iconKey) {
    switch (iconKey) {
      case 'electrical':
        return Icons.power_outlined;
      case 'hardware':
        return Icons.build_outlined;
      case 'lighting':
        return Icons.lightbulb_outline;
      case 'plumbing':
        return Icons.water_drop_outlined;
      case 'sanitary':
        return Icons.sanitizer_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
