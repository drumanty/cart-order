import 'estimate_service.dart';
import 'cart_screen.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'shop_settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'catalog_support.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String? productId;
  const ProductDetailsScreen({super.key, this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with TickerProviderStateMixin, CatalogState<ProductDetailsScreen> {
  int _selectedImageIndex = 0;
  bool _addingToCart = false;
  Future<void> _addToCart() async {
    if (!_canUseBuyerActions || _addingToCart) return;
    final id = widget.productId;
    if (id == null) return;
    setState(() => _addingToCart = true);
    try {
      await EstimateService.addProduct(id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(EstimateService.error(e))));
      }
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  bool _sendingSample = false;
  bool _sampleSent = false;
  Future<void> _requestSample() async {
    if (!_canUseBuyerActions || _sendingSample || _sampleSent) return;
    setState(() => _sendingSample = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final productId = widget.productId;
      if (user == null || productId == null) {
        throw StateError('Please sign in as a Buyer.');
      }
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final buyer = profile.data() ?? <String, dynamic>{};
      if (buyer['userType'] != 'Buyer' ||
          buyer['accountStatus'] != 'approved') {
        throw StateError('Only approved Buyers can request samples.');
      }
      final product = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      final p = product.data();
      if (p == null || p['isActive'] != true || p['status'] != 'Approved') {
        throw StateError('This product is no longer available.');
      }
      await FirebaseFirestore.instance.collection('sample_requests').add({
        'buyerId': user.uid,
        'userName': '${buyer['firstName'] ?? ''} ${buyer['lastName'] ?? ''}'
            .trim(),
        'userMobile': (buyer['mobileNumber'] ?? '').toString(),
        'buyerEmail': user.email ?? '',
        'buyerAddress': (buyer['shopAddress'] ?? '').toString(),
        'shopName': (buyer['shopName'] ?? '').toString(),
        'productID': productId,
        'productName': (p['productName'] ?? '').toString(),
        'sellerId': (p['sellerId'] ?? '').toString(),
        'sellerShopName': (p['sellerShopName'] ?? '').toString(),
        'sampleImageUrl': (p['frontImage'] ?? '').toString(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _sampleSent = true);
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Sample request submitted'),
          content: const Text(
            'Your sample request has been sent to our support team.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not save sample request. Please check your connection and access permissions.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingSample = false);
    }
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleSubscription;
  String? _roleUid;
  String? _userRole;
  bool _approvedBuyer = false;
  bool _roleLoading = true;
  bool _roleFailed = false;
  bool get _canUseBuyerActions =>
      _approvedBuyer &&
      _roleUid != null &&
      FirebaseAuth.instance.currentUser?.uid == _roleUid;

  void _watchUserRole() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        _roleSubscription?.cancel();
        if (!mounted) return;
        setState(() {
          _roleUid = user?.uid;
          _userRole = null;
          _approvedBuyer = false;
          _roleLoading = user != null;
          _roleFailed = false;
        });
        if (user == null) return;
        final uid = user.uid;
        _roleSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots()
            .listen(
              (doc) {
                if (!mounted || _roleUid != uid) return;
                final data = doc.data();
                setState(() {
                  _userRole = data?['userType']?.toString();
                  _approvedBuyer =
                      _userRole == 'Buyer' &&
                      data?['accountStatus'] == 'approved';
                  _roleLoading = false;
                  _roleFailed = !doc.exists;
                });
              },
              onError: (Object error) {
                if (!mounted || _roleUid != uid) return;
                setState(() {
                  _approvedBuyer = false;
                  _roleLoading = false;
                  _roleFailed = true;
                });
              },
            );
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _approvedBuyer = false;
          _roleLoading = false;
          _roleFailed = true;
        });
      },
    );
  }

  String get _buyerActionMessage {
    if (_roleLoading) return 'Checking account permissions…';
    if (_roleFailed) return 'Unable to verify account permissions.';
    if (_userRole == 'Buyer') return 'An approved Buyer account is required.';
    return 'This function is only for buyers.';
  }

  // Animation controllers
  AnimationController? _blinkingController;
  AnimationController? _moreProductsController;

  Map<String, dynamic> _product = {};
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _detailsStream;
  String get _packages => _product['howManyProductsInUnit'] ?? '';
  String get _material => _product['description'] ?? '';
  String get _warranty => (_product['warranty'] ?? '').isEmpty
      ? 'Not specified'
      : _product['warranty'];
  String get _currentRating => _product['unitTypes'] ?? '';
  String get _productMrp => _product['mrp'] ?? '';
  String get _sellingPrice => _product['sellingPrice'] ?? '';
  String get _moq => _product['minOrderQuantity'] ?? '';
  List<String> get _images => [
    'frontImage',
    'backImage',
    'sideImage',
  ].map((k) => (_product[k] ?? '').toString()).toList();
  List<Map<String, dynamic>> get _moreProducts => catalogProducts
      .where(
        (p) =>
            (_product['sellerId'] ?? '').toString().isNotEmpty &&
            p['sellerId'] == _product['sellerId'] &&
            p['id'] != widget.productId &&
            p['isActive'] == true &&
            p['status'] == 'Approved',
      )
      .take(20)
      .map(
        (p) => {
          ...p,
          'title': p['productName'],
          'price': p['sellingPrice'],
          'icon': Icons.inventory_2_outlined,
        },
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _watchUserRole();
    _detailsStream = widget.productId == null || widget.productId!.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('products')
              .doc(widget.productId)
              .snapshots();

    // Minimum order badge blinking animation
    _blinkingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // More Products continuous vertical animation
    _moreProductsController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _roleSubscription?.cancel();
    _blinkingController?.dispose();
    _moreProductsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_detailsStream == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Product Details')),
        body: Center(child: Text('Select a product from the catalog.')),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _detailsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text('Product Details')),
            body: Center(child: Text(catalogError(snapshot.error!))),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: Text('Product Details')),
            body: Center(child: Text('This product is no longer available.')),
          );
        }
        _product = catalogProduct(snapshot.data!);
        return _buildDetails(context);
      },
    );
  }

  Widget _buildDetails(BuildContext context) {
    final Widget minOrderBadge = ShopMinimumBadge(
      sellerId: _product['sellerId'],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ============================================================
            // MAIN SCROLLABLE CONTENT
            // ============================================================
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======================================================
                    // LEFT COLUMN
                    // ======================================================
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Image Container
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: catalogImage(
                              _images[_selectedImageIndex],
                              height: 200,
                            ),
                          ),

                          SizedBox(height: 12),

                          // Thumbnails
                          Row(
                            children: List.generate(3, (index) {
                              final isSelected = _selectedImageIndex == index;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImageIndex = index;
                                  });
                                },
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Color(0xFF0052FF)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: catalogImage(
                                    _images[index],
                                    width: 42,
                                    height: 42,
                                  ),
                                ),
                              );
                            }),
                          ),

                          SizedBox(height: 16),

                          // Product Title
                          Text(
                            _product['productName'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          SizedBox(height: 6),

                          // Rating
                          Row(
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    _product['ratings'] > index
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                _product['reviewCount'] == 0
                                    ? 'Not rated'
                                    : '${_product['reviewCount']} reviews',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 10),

                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _sellingPrice,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _productMrp,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          Text(
                            '${_product['stockStatus']} • ${_product['status']}',
                            style: TextStyle(
                              color: _product['inStock'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          SizedBox(height: 8),
                          // Product Highlights
                          Text(
                            'Product Highlights',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          SizedBox(height: 12),

                          _buildHighlightRow(
                            icon: Icons.currency_rupee_outlined,
                            label: 'Product Mrp',
                            value: _productMrp,
                          ),

                          _buildHighlightRow(
                            icon: Icons.currency_rupee_outlined,
                            label: 'Selling Price',
                            value: _sellingPrice,
                          ),

                          _buildHighlightRow(
                            icon: Icons.electric_meter_outlined,
                            label: 'Unit Type',
                            value: _currentRating,
                          ),

                          _buildHighlightRow(
                            icon: Icons.widgets_outlined,
                            label: 'Packages',
                            value: _packages,
                          ),

                          _buildHighlightRow(
                            icon: Icons.production_quantity_limits,
                            label: 'Minimum Order Quantity',
                            value: _moq.toString(),
                            isLongText: true,
                          ),
                          _buildHighlightRow(
                            icon: Icons.verified_outlined,
                            label: 'Warranty',
                            value: _warranty,
                          ),

                          _buildHighlightRow(
                            icon: Icons.description_outlined,
                            label: 'Description',
                            value: _material,
                            isLongText: true,
                          ),

                          SizedBox(height: 16),
                        ],
                      ),
                    ),

                    SizedBox(width: 12),

                    // ======================================================
                    // RIGHT COLUMN
                    // ======================================================
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ==================================================
                          // STORE DETAILS
                          // ==================================================
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF0052FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.storefront,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 10),

                                Text(
                                  'Seller ID: ${_product['sellerId']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                SizedBox(height: 4),

                                Text(
                                  _product['sellerShopName'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 10),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        _product['sellerShopAddress'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12),

                                // Blinking Minimum Order Badge
                                if (_blinkingController != null)
                                  FadeTransition(
                                    opacity: _blinkingController!,
                                    child: minOrderBadge,
                                  )
                                else
                                  minOrderBadge,
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // ==================================================
                          // MORE PRODUCTS HEADER
                          // ==================================================
                          Padding(
                            padding: EdgeInsets.only(
                              left: 16.0,
                            ), // Adjust the value as needed
                            child: Text(
                              'More Products',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0052FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          SizedBox(height: 10),

                          // ==================================================
                          // CONTINUOUS BOTTOM -> TOP PRODUCTS
                          // ==================================================
                          _buildMoreProductsAnimation(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ============================================================
            // FIXED BOTTOM ACTION BAR
            // ============================================================
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Sample Button
                      Expanded(
                        flex: 4,
                        child: OutlinedButton(
                          onPressed:
                              _canUseBuyerActions &&
                                  !_sendingSample &&
                                  !_sampleSent
                              ? _requestSample
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: _canUseBuyerActions
                                  ? Color(0xFF0052FF)
                                  : Colors.grey,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: _canUseBuyerActions
                                        ? Color(0xFF0052FF)
                                        : Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Sample',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _canUseBuyerActions
                                          ? Color(0xFF0052FF)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _sendingSample
                                    ? 'Submitting…'
                                    : _sampleSent
                                    ? 'Request sent'
                                    : 'Get product sample',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 12),

                      // Add To Cart Button
                      Expanded(
                        flex: 5,
                        child: ElevatedButton(
                          onPressed:
                              _canUseBuyerActions &&
                                  _product['inStock'] == true &&
                                  _product['isActive'] == true &&
                                  !_addingToCart
                              ? _addToCart
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Color(0xFF0052FF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                _addingToCart ? 'Adding…' : 'Add to Cart',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_canUseBuyerActions) ...[
                    const SizedBox(height: 8),
                    Text(
                      _buyerActionMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================================
  // MORE PRODUCTS ANIMATION
  // ======================================================================

  Widget _buildMoreProductsAnimation() {
    double itemHeight = 52.0;
    double viewportHeight = 380.0;

    final int itemCount = _moreProducts.length;
    if (catalogLoading || catalogFailure != null) {
      return SizedBox(height: viewportHeight, child: catalogNotice());
    }
    if (itemCount == 0) {
      return SizedBox(
        height: viewportHeight,
        child: Center(child: Text('No other products from this seller.')),
      );
    }

    return SizedBox(
      height: viewportHeight,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _moreProductsController!,
          builder: (context, child) {
            final double totalHeight = itemCount * itemHeight;
            final double offset = _moreProductsController!.value * totalHeight;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: List.generate(itemCount, (index) {
                double y = (index * itemHeight - offset) % totalHeight;

                if (y < 0) {
                  y += totalHeight;
                }

                return Positioned(
                  left: 0,
                  right: 0,
                  top: y,
                  height: itemHeight,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsScreen(
                          productId: _moreProducts[index]['id'],
                        ),
                      ),
                    ),
                    child: _buildMoreProductItem(_moreProducts[index]),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMoreProductItem(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item['icon'] as IconData,
              size: 18,
              color: Colors.grey.shade700,
            ),
          ),

          SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 2),

                Text(
                  item['price'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0052FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // PRODUCT HIGHLIGHT ROW
  // ======================================================================

  Widget _buildHighlightRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLongText = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: isLongText
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Color(0xFF0052FF)),

              SizedBox(width: 8),

              SizedBox(
                width: 75,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}
