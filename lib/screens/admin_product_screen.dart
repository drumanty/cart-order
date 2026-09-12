import 'package:flutter/material.dart';
import 'add_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = [
    'Wires & Cables',
    'Switches & Accessories',
    'Lighting & LEDs',
    'Switchgears & Automation',
  ];

  final List<Map<String, dynamic>> _products = [
    {
      'id': 'PRD-801',
      'productName': '1.5 Sqmm Copper Flexible Wire (90m Roll)',
      'category': 'Wires & Cables',
      'unitPrice': '₹ 1,150',
      'mrp': '₹ 1,800',
      'sellingPrice': '₹ 1,250',
      'mrpUnitPrice': '₹ 1,600',
      'minOrderQuantity': '50 Units',
      'howManyProductsInUnit': '10 Rolls',
      'unitTypes': 'Box / Bundle',
      'ratings': 4.8,
      'warranty': '12 Months Brand Warranty',
      'description':
          'High-grade flame retardant copper wire suitable for domestic and commercial electrical fittings.',
      'frontImage': 'https://picsum.photos/id/1/300/300',
      'backImage': 'https://picsum.photos/id/2/300/300',
      'sideImage': 'https://picsum.photos/id/3/300/300',
      'status': 'Approved',
    },
    {
      'id': 'PRD-802',
      'productName': '4-Way Modular Switch Board Plate',
      'category': 'Switches & Accessories',
      'unitPrice': '₹ 85',
      'mrp': '₹ 150',
      'sellingPrice': '₹ 95',
      'mrpUnitPrice': '₹ 140',
      'minOrderQuantity': '50 Units',
      'howManyProductsInUnit': '20 Pieces',
      'unitTypes': 'Carton',
      'ratings': 4.3,
      'warranty': '6 Months Replacement Warranty',
      'description':
          'Polycarbonate modular cover plate with anti-bacterial coating.',
      'frontImage': 'https://picsum.photos/id/10/300/300',
      'backImage': 'https://picsum.photos/id/11/300/300',
      'sideImage': 'https://picsum.photos/id/12/300/300',
      'status': 'Out of Stock',
    },
  ];

  void _updateProductStatus(Map<String, dynamic> product, String newStatus) {
    setState(() {
      product['status'] = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['productName']} set to "$newStatus"'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _deleteProduct(int index) {
    final deletedName = _products[index]['productName'];
    setState(() {
      _products.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deletedName removed from inventory'),
        duration: const Duration(seconds: 1),
      ),
    );
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
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        setState(() {
                          _categories.add(categoryController.text.trim());
                        });
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
    final newProduct = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(categories: _categories),
      ),
    );

    if (newProduct != null) {
      setState(() {
        _products.insert(0, newProduct);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New product added to inventory!')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Inactive':
        return Colors.orange;
      case 'Out of Stock':
        return Colors.grey.shade700;
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
      final status = (product['status'] ?? '').toString().toLowerCase();

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
          const SizedBox(height: 8),
          Expanded(
            child: _filteredProducts.isEmpty
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
                                'Category: ${product['category']} • SP: ${product['sellingPrice']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
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
                                value: '${product['ratings']} / 5.0',
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
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: product['status'] == 'Approved'
                                          ? null
                                          : () => _updateProductStatus(
                                              product,
                                              'Approved',
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Approve',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: product['status'] == 'Inactive'
                                          ? null
                                          : () => _updateProductStatus(
                                              product,
                                              'Inactive',
                                            ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange.shade800,
                                        side: BorderSide(
                                          color: product['status'] == 'Inactive'
                                              ? Colors.orange
                                              : Colors.grey.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Inactive',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          product['status'] == 'Out of Stock'
                                          ? null
                                          : () => _updateProductStatus(
                                              product,
                                              'Out of Stock',
                                            ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey.shade800,
                                        side: BorderSide(
                                          color:
                                              product['status'] ==
                                                  'Out of Stock'
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade300,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Out of Stock',
                                        style: TextStyle(fontSize: 10),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    onPressed: () {
                                      final originalIndex = _products.indexOf(
                                        product,
                                      );
                                      if (originalIndex != -1) {
                                        _deleteProduct(originalIndex);
                                      }
                                    },
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
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
