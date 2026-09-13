import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'catalog_support.dart';
import 'package:flutter/material.dart';

class AddProductScreen extends StatefulWidget {
  final List<String> categories;

  const AddProductScreen({super.key, required this.categories});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _mrpUnitPriceController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _howManyInUnitController = TextEditingController();
  final _unitTypeController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _descController = TextEditingController();

  late String _selectedCategory;
  String? _sellerId;
  bool _saving = false;
  final _sellerStream = FirebaseFirestore.instance
      .collection('users')
      .where('userType', isEqualTo: 'Seller')
      .snapshots();
  List<String> get _categoryOptions => widget.categories.toSet().toList();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.isNotEmpty
        ? widget.categories.first
        : 'General';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _unitPriceController.dispose();
    _mrpUnitPriceController.dispose();
    _minOrderController.dispose();
    _howManyInUnitController.dispose();
    _unitTypeController.dispose();
    _warrantyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitProduct() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_sellerId == null) return;
    final prices = [
      _sellingPriceController,
      _mrpController,
      _unitPriceController,
      _mrpUnitPriceController,
    ];
    final numbers = <double>[];
    for (final controller in prices) {
      final value = controller.text.trim().isEmpty
          ? 0.0
          : double.tryParse(controller.text.trim());
      if (value == null || !value.isFinite || value < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter valid non-negative prices, using digits and a decimal point.',
            ),
          ),
        );
        return;
      }
      numbers.add(value);
    }
    final moq = int.tryParse(_minOrderController.text.trim());
    final quantity = int.tryParse(_howManyInUnitController.text.trim());
    if (moq == null || moq < 1 || quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Minimum quantity and quantity in a unit must be positive whole numbers.',
          ),
        ),
      );
      return;
    }
    if (numbers[1] < numbers[0] || numbers[3] < numbers[2]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MRP must be at least the corresponding selling/unit price.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Signed out');
      final seller = await FirebaseFirestore.instance
          .collection('users')
          .doc(_sellerId)
          .get();
      final profile = seller.data();
      if (profile == null ||
          profile['userType'] != 'Seller' ||
          profile['accountStatus'] != 'approved') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Choose an approved seller.')),
          );
        }
        return;
      }
      final doc = FirebaseFirestore.instance.collection('products').doc();
      await doc.set({
        'productName': _nameController.text.trim(),
        'category': _selectedCategory,
        'sellerId': seller.id,
        'sellerName':
            '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim(),
        'sellerShopName': (profile['shopName'] ?? '').toString(),
        'sellerShopAddress': (profile['shopAddress'] ?? '').toString(),
        'sellingPrice': numbers[0],
        'mrp': numbers[1],
        'unitPrice': numbers[2],
        'mrpUnitPrice': numbers[3],
        'minOrderQuantity': moq,
        'howManyProductsInUnit': quantity,
        'unitTypes': _unitTypeController.text.trim(),
        'warranty': _warrantyController.text.trim(),
        'description': _descController.text.trim(),
        'frontImage': '',
        'backImage': '',
        'sideImage': '',
        'ratings': 0,
        'reviewCount': 0,
        'status': 'Approved',
        'isActive': true,
        'inStock': true,
        'stockStatus': 'In Stock',
        'createdBy': user.uid,
        'updatedBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(catalogError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sellerField() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _sellerStream,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text(catalogError(snapshot.error!));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final sellers = snapshot.data!.docs
          .where((d) => d.data()['accountStatus'] == 'approved')
          .toList();
      if (sellers.isEmpty) {
        return const Text('Approve a Seller account before adding products.');
      }
      final selected = sellers.any((d) => d.id == _sellerId) ? _sellerId : null;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: _inputDecoration('Assign Seller'),
        items: sellers
            .map(
              (d) => DropdownMenuItem(
                value: d.id,
                child: Text(
                  '${d.data()['shopName'] ?? ''} — ${d.data()['firstName'] ?? ''} (${d.data()['email'] ?? ''})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: _saving ? null : (v) => setState(() => _sellerId = v),
        validator: (v) => v == null ? 'Select an approved seller' : null,
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Images Section Header
              const Text(
                'Product Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildImagePlaceholder('Front View'),
                  const SizedBox(width: 8),
                  _buildImagePlaceholder('Back View'),
                  const SizedBox(width: 8),
                  _buildImagePlaceholder('Side View'),
                ],
              ),
              const SizedBox(height: 20),

              _sellerField(),
              const SizedBox(height: 16),
              // Basic Details
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  'Product Name',
                  hint: 'e.g. Copper Cable Wire',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter product name' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryOptions.contains(_selectedCategory)
                    ? _selectedCategory
                    : null,
                validator: (v) => v == null ? 'Add a category first' : null,
                decoration: _inputDecoration('Category'),
                items: _categoryOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 20),

              // Pricing Breakdown Section
              const Text(
                'Pricing Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPriceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        'Selling Price (₹)',
                        hint: '1250',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('MRP (₹)', hint: '1800'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        'Unit Price (₹)',
                        hint: '1150',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mrpUnitPriceController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        'MRP Unit Price (₹)',
                        hint: '1600',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Inventory & Packaging Details
              const Text(
                'Packaging & Specifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minOrderController,
                      decoration: _inputDecoration(
                        'Min Order Quantity ',
                        hint: '50',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _howManyInUnitController,
                      decoration: _inputDecoration('Qty in Unit', hint: '10'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitTypeController,
                      decoration: _inputDecoration(
                        'Unit Type',
                        hint: 'Box / Bundle',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _warrantyController,
                      decoration: _inputDecoration(
                        'Warranty',
                        hint: '12 Months',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputDecoration(
                  'Product Description',
                  hint: 'Write short details...',
                ),
              ),
              const SizedBox(height: 28),

              // Save Product Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _saving ? null : _submitProduct,
                  child: Text(
                    _saving ? 'Saving...' : 'Save Product',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5),
      ),
    );
  }

  Widget _buildImagePlaceholder(String label) {
    return Expanded(
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              color: Color(0xFF0052FF),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
