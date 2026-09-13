import 'shop_settings.dart';
import 'edit_product_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'catalog_support.dart';
import 'package:flutter/material.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen>
    with CatalogState<MyProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get sellerProductsOnly => true;
  List<Map<String, dynamic>> get _products => catalogProducts;
  final Set<String> _busy = {};

  Future<void> _updateProductStatus(
    Map<String, dynamic> product,
    String newStatus,
  ) async {
    final id = product['id'] as String;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      if (newStatus != 'In Stock' && newStatus != 'Out of Stock') return;
      await FirebaseFirestore.instance.collection('products').doc(id).update({
        'inStock': newStatus == 'In Stock',
        'stockStatus': newStatus,
        'updatedBy': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(catalogError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Inactive':
        return Colors.orange;
      case 'Out of Stock':
        return Colors.red;
      case 'Pending Approval':
      default:
        return const Color(0xFF0052FF);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.trim().isEmpty) {
      return _products;
    }

    final query = _searchQuery.trim().toLowerCase();

    return _products.where((product) {
      final productName = (product['productName'] ?? '')
          .toString()
          .toLowerCase();
      final productId = (product['id'] ?? '').toString().toLowerCase();
      final category = (product['category'] ?? '').toString().toLowerCase();
      final status =
          '${product['status']} ${product['stockStatus']} ${product['sellerName']}'
              .toLowerCase();

      return productName.contains(query) ||
          productId.contains(query) ||
          category.contains(query) ||
          status.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          const ShopMinimumEditor(),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 21,
                  color: Colors.grey,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 19),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF0052FF),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (categoryFailure != null) catalogNotice(),
          const SizedBox(height: 8),
          Expanded(
            child: catalogLoading || catalogFailure != null
                ? catalogNotice()
                : _filteredProducts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching by product name, ID, category, or status.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final Color statusColor = _getStatusColor(
                        product['status'],
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: PageStorageKey(product['id']),
                            tilePadding: const EdgeInsets.all(16),
                            childrenPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product['frontImage'],
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 52,
                                      height: 52,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    product['productName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product['status'],
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Category: ${product['category']} • SP: ${product['sellingPrice']} • ${product['stockStatus']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: product['inStock'] == false
                                      ? Colors.red
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Product Images (Front, Back, Side)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildImagePreview(
                                    product['frontImage'],
                                    'Front View',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildImagePreview(
                                    product['backImage'],
                                    'Back View',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildImagePreview(
                                    product['sideImage'],
                                    'Side View',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildPriceMetric(
                                            'Selling Price',
                                            product['sellingPrice'],
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildPriceMetric(
                                            'MRP',
                                            product['mrp'],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildPriceMetric(
                                            'Unit Price',
                                            product['unitPrice'],
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildPriceMetric(
                                            'MRP Unit Price',
                                            product['mrpUnitPrice'],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                icon: Icons.category_outlined,
                                label: 'Product Category',
                                value: product['category'],
                              ),
                              _buildDetailRow(
                                icon: Icons.shopping_bag_outlined,
                                label: 'Minimum Order Quantity',
                                value: product['minOrderQuantity'],
                              ),
                              _buildDetailRow(
                                icon: Icons.inventory_outlined,
                                label: 'Quantity in 1 Unit',
                                value: product['howManyProductsInUnit'],
                              ),
                              _buildDetailRow(
                                icon: Icons.widgets_outlined,
                                label: 'Unit Types',
                                value: product['unitTypes'],
                              ),
                              _buildDetailRow(
                                icon: Icons.star_outline,
                                label: 'Product Rating',
                                value: product['reviewCount'] == 0
                                    ? 'Not rated'
                                    : '${product['ratings']} / 5.0',
                              ),
                              _buildDetailRow(
                                icon: Icons.verified_user_outlined,
                                label: 'Warranty',
                                value: product['warranty'],
                              ),
                              _buildDetailRow(
                                icon: Icons.description_outlined,
                                label: 'Description',
                                value: product['description'],
                              ),
                              _buildDetailRow(
                                icon: Icons.storefront,
                                label: 'Seller',
                                value:
                                    product['sellerShopName'].toString().isEmpty
                                    ? product['sellerName']
                                    : product['sellerShopName'],
                              ),
                              _buildDetailRow(
                                icon: Icons.inventory_2_outlined,
                                label: 'Stock',
                                value: product['stockStatus'],
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _busy.contains(product['id'])
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditProductScreen(
                                            productId: product['id'],
                                          ),
                                        ),
                                      ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit Product Details'),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busy.contains(product['id'])
                                          ? null
                                          : () => _updateProductStatus(
                                              product,
                                              product['inStock'] == true
                                                  ? 'Out of Stock'
                                                  : 'In Stock',
                                            ),
                                      child: Text(
                                        product['inStock'] == true
                                            ? 'Mark Out of Stock'
                                            : 'Mark In Stock',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String imageUrl, String label) {
    return Expanded(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              height: 80,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 80,
                color: Colors.grey.shade100,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceMetric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: value == 'Out of Stock'
                        ? Colors.red
                        : Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
