import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'catalog_support.dart';
import 'package:flutter/material.dart';
import 'add_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen>
    with CatalogState<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<String> get _categories => catalogCategories;
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
      final stock = newStatus == 'In Stock' || newStatus == 'Out of Stock';
      await FirebaseFirestore.instance.collection('products').doc(id).update({
        if (stock) 'inStock': newStatus == 'In Stock',
        if (stock) 'stockStatus': newStatus,
        if (!stock) 'status': newStatus,
        if (!stock) 'isActive': newStatus == 'Approved',
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

  Future<void> _deleteProduct(int index) async {
    final product = _products[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(product['productName']),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product['id'])
          .delete();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(catalogError(error))));
      }
    }
  }

  void _openAddCategorySheet() {
    final TextEditingController categoryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g. Cables & Conductors',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a category name';
                    }
                    if (_categories.contains(value.trim())) {
                      return 'Category already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('categories')
                              .doc(
                                Uri.encodeComponent(
                                  categoryController.text.trim().toLowerCase(),
                                ),
                              )
                              .set({
                                'name': categoryController.text.trim(),
                                'createdBy':
                                    FirebaseAuth.instance.currentUser!.uid,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(catalogError(error))),
                            );
                          }
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Category "${categoryController.text.trim()}" added successfully!',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Save Category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToAddProductScreen() async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a category first.')));
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(categories: _categories),
      ),
    );
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
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Admin Product Inventory'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAddProductScreen,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Product',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openAddCategorySheet,
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: const Text(
                      'Add Category',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0052FF),
                      side: const BorderSide(color: Color(0xFF0052FF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        _busy.contains(product['id']) ||
                                            product['status'] == 'Approved'
                                        ? null
                                        : () => _updateProductStatus(
                                            product,
                                            'Approved',
                                          ),
                                    child: const Text('Approve'),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange.shade800,
                                    ),
                                    onPressed:
                                        _busy.contains(product['id']) ||
                                            product['status'] == 'Inactive'
                                        ? null
                                        : () => _updateProductStatus(
                                            product,
                                            'Inactive',
                                          ),
                                    child: const Text('Inactive'),
                                  ),
                                  OutlinedButton(
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
                                          ? 'Out of Stock'
                                          : 'In Stock',
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _busy.contains(product['id'])
                                        ? null
                                        : () => _deleteProduct(
                                            _products.indexOf(product),
                                          ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Delete Product',
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
