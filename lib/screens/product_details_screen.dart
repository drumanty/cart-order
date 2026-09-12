import 'package:flutter/material.dart';
import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with TickerProviderStateMixin {
  int _selectedImageIndex = 0;

  // Animation controllers
  AnimationController? _blinkingController;
  AnimationController? _moreProductsController;

  // Product Highlights Data
  final String _packages = '5kg';

  final String _material = 'High-quality,durable and long lasting capacity.';

  final String _warranty = '2 Years Manufacturer Warranty';

  final String _currentRating = ' 6A';

  final int _productMrp = 400;

  final int _sellingPrice = 350;
  final int _moq = 100;

  // More Products
  final List<Map<String, dynamic>> _moreProducts = [
    {
      'title': 'LED Bulb 12W Super Bright White',
      'price': '₹220',
      'icon': Icons.lightbulb_outline,
    },
    {
      'title': 'MCB 1P 32A Circuit Breaker',
      'price': '₹290',
      'icon': Icons.toggle_on_outlined,
    },
    {
      'title': 'Copper Wire 2.5mm Heavy Duty',
      'price': '₹2,250',
      'icon': Icons.donut_large_outlined,
    },
    {
      'title': '1 Gang Switch Panel',
      'price': '₹95',
      'icon': Icons.crop_square_outlined,
    },
    {
      'title': 'Ceiling Fan 56" High Speed',
      'price': '₹3,500',
      'icon': Icons.toys_outlined,
    },
    {
      'title': 'Power Strip 4 Way Surge Protector',
      'price': '₹550',
      'icon': Icons.power_outlined,
    },
    {
      'title': 'Power Strip 4 Way Surge Protector',
      'price': '₹550',
      'icon': Icons.power_outlined,
    },

    {
      'title': 'Power Strip 4 Way Surge Protector',
      'price': '₹550',
      'icon': Icons.power_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Minimum order badge blinking animation
    _blinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // More Products continuous vertical animation
    _moreProductsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _blinkingController?.dispose();
    _moreProductsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Minimum Order Badge
    Widget minOrderBadge = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0052FF), width: 0.8),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 14,
            color: Color(0xFF0052FF),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              'Minimum Order\namount ₹1,000',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0052FF),
              ),
            ),
          ),
        ],
      ),
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
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
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.power,
                                size: 100,
                                color: Colors.black54,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

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
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0052FF)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.power_input,
                                    size: 20,
                                    color: Colors.black54,
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 16),

                          // Product Title
                          const Text(
                            'Universal Wall Socket',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Rating
                          Row(
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '(256 reviews)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                '₹4.25',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹5.00',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Product Highlights
                          const Text(
                            'Product Highlights',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildHighlightRow(
                            icon: Icons.currency_rupee_outlined,
                            label: 'Product Mrp',
                            value: '₹$_productMrp',
                          ),

                          _buildHighlightRow(
                            icon: Icons.currency_rupee_outlined,
                            label: 'Selling Price',
                            value: '₹$_sellingPrice',
                          ),

                          _buildHighlightRow(
                            icon: Icons.electric_meter_outlined,
                            label: 'Current Rating',
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
                            label: 'Material',
                            value: _material,
                            isLongText: true,
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

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
                            padding: const EdgeInsets.all(12),
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
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0052FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.storefront,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                Text(
                                  'Shop ID: ELEC12345',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                const Text(
                                  'Dipak Marketing',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        '456 Power Street,\nTech City, CA 90210',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

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

                          const SizedBox(height: 16),

                          // ==================================================
                          // MORE PRODUCTS HEADER
                          // ==================================================
                          const Padding(
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

                          const SizedBox(height: 10),

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Sample Button
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFF0052FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: Color(0xFF0052FF),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Sample',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Get product sample',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Add To Cart Button
                  Expanded(
                    flex: 5,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF0052FF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Add to Cart',
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
    const double itemHeight = 52.0;
    const double viewportHeight = 380.0;

    final int itemCount = _moreProducts.length;

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
                  child: _buildMoreProductItem(_moreProducts[index]),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item['icon'] as IconData,
              size: 18,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                Text(
                  item['price'] as String,
                  style: const TextStyle(
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
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: isLongText
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0052FF)),

              const SizedBox(width: 8),

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
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}
