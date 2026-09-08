import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Uploaded Products',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: currentUser == null
          ? const Center(child: Text('Please log in to view your products.'))
          : Column(
              children: [
                // Search Bar Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search product by name or category...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF0052FF),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0052FF)),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .where('sellerId', isEqualTo: currentUser!.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading products: ${snapshot.error}',
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0052FF),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Filter products based on search query
                      final allProducts = snapshot.data!.docs;
                      final filteredProducts = allProducts.where((doc) {
                        final product = doc.data() as Map<String, dynamic>;
                        final name =
                            (product['productName'] ??
                                    product['title'] ??
                                    product['name'] ??
                                    '')
                                .toString()
                                .toLowerCase();
                        final category = (product['category'] ?? '')
                            .toString()
                            .toLowerCase();

                        return name.contains(_searchQuery) ||
                            category.contains(_searchQuery);
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Header Banner
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Showing ${filteredProducts.length} of ${allProducts.length} Items',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Live on Store',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Products List
                          Expanded(
                            child: filteredProducts.isEmpty
                                ? Center(
                                    child: Text(
                                      'No products match "$_searchQuery"',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16.0),
                                    itemCount: filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      final productDoc =
                                          filteredProducts[index];
                                      final product =
                                          productDoc.data()
                                              as Map<String, dynamic>;

                                      return _buildProductCard(
                                        context: context,
                                        productId: productDoc.id,
                                        product: product,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductCard({
    required BuildContext context,
    required String productId,
    required Map<String, dynamic> product,
  }) {
    final String productName =
        product['productName'] ?? product['title'] ?? product['name'] ?? 'N/A';
    final String category = product['category'] ?? 'N/A';
    final String unitOfProduct =
        product['unitOfProduct'] ?? product['unit'] ?? 'Pcs';
    final String unitPrice = product['unitPrice']?.toString() ?? '0';
    final String totalUnitsPerBox =
        product['totalUnitsPerBox']?.toString() ??
        product['boxQuantity']?.toString() ??
        '1';
    final String mrp = product['mrp']?.toString() ?? '0';
    final String boxSellingPrice =
        product['boxSellingPrice']?.toString() ??
        product['price']?.toString() ??
        '0';
    final String moq =
        product['minOrderQuantity']?.toString() ??
        product['moq']?.toString() ??
        '1';
    final String replaceWarranty =
        product['replaceWarranty'] ?? product['warranty'] ?? 'No Warranty';
    final String description =
        product['description'] ?? 'No description provided.';

    // Three view image URLs with fallbacks
    final String frontImage =
        product['frontImageUrl'] ??
        product['imageUrl'] ??
        product['image'] ??
        '';
    final String sideImage = product['sideImageUrl'] ?? '';
    final String backImage = product['backImageUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Category, Title & Action Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF2FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0052FF),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDelete(context, productId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Product',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              productName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Three Product Views Row (Front, Side, Back)
            Row(
              children: [
                Expanded(
                  child: _buildImageView(label: 'Front View', url: frontImage),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildImageView(label: 'Side View', url: sideImage),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildImageView(label: 'Back View', url: backImage),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
            ),

            // Pricing & Quantity Grid Breakdown
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Unit Price',
                          value: '₹$unitPrice / $unitOfProduct',
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          label: 'MRP',
                          value: '₹$mrp',
                          isLineThrough: true,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Box Selling Price',
                          value: '₹$boxSellingPrice',
                          isHighlighted: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Units / Box',
                          value: '$totalUnitsPerBox $unitOfProduct',
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Min Order Qty',
                          value: '$moq Box(es)',
                        ),
                      ),
                      Expanded(
                        child: _buildMetricItem(
                          label: 'Warranty / Replace',
                          value: replaceWarranty,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Description Section
            Text(
              'Description:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageView({required String label, required String url}) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 70,
            width: double.infinity,
            color: const Color(0xFFF0F4FF),
            child: url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                      size: 24,
                    ),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: Color(0xFF0052FF),
                    size: 24,
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    bool isHighlighted = false,
    bool isLineThrough = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? const Color(0xFF0052FF) : Colors.black87,
            decoration: isLineThrough ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEBF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_shopping_cart,
                size: 48,
                color: Color(0xFF0052FF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Products Uploaded Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you upload products, they will appear here for you to manage.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
          'Are you sure you want to remove this product from your inventory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
