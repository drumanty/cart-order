import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'catalog_support.dart';
import 'cloudinary_upload_service.dart';

class AddProductScreen extends StatefulWidget {
  final List<String> categories;
  const AddProductScreen({super.key, required this.categories});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sellerPriceController = TextEditingController();
  final _marginController = TextEditingController();
  final _actualSellingPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _mrpUnitPriceController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _howManyInUnitController = TextEditingController();
  final _unitTypeController = TextEditingController();
  final _currentRatingController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _descController = TextEditingController();
  late String _selectedCategory;
  String? _sellerId;
  bool _saving = false;
  XFile? _frontImage;
  XFile? _backImage;
  Uint8List? _frontImageBytes;
  Uint8List? _backImageBytes;
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
    for (final controller in [
      _sellerPriceController,
      _marginController,
      _mrpController,
      _howManyInUnitController,
    ]) {
      controller.addListener(_recalculatePrices);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _sellerPriceController,
      _marginController,
      _actualSellingPriceController,
      _mrpController,
      _unitPriceController,
      _mrpUnitPriceController,
      _minOrderController,
      _howManyInUnitController,
      _unitTypeController,
      _currentRatingController,
      _warrantyController,
      _descController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) {
    final normalized = value
        .trim()
        .replaceAll('₹', '')
        .replaceAll('%', '')
        .replaceAll(',', '');
    return double.tryParse(normalized);
  }

  void _setCalculatedText(TextEditingController controller, double? value) {
    final text = value == null ? '' : value.toStringAsFixed(2);
    if (controller.text != text) controller.text = text;
  }

  void _recalculatePrices() {
    final sellerPrice = _number(_sellerPriceController.text);
    final margin = _number(_marginController.text);
    final quantity = int.tryParse(_howManyInUnitController.text.trim());
    final mrp = _number(_mrpController.text);
    if (sellerPrice == null ||
        sellerPrice < 0 ||
        margin == null ||
        margin < 0) {
      _setCalculatedText(_actualSellingPriceController, null);
      _setCalculatedText(_unitPriceController, null);
      _setCalculatedText(_mrpUnitPriceController, null);
      return;
    }
    final actualSellingPrice = sellerPrice * (1 + margin / 100);
    _setCalculatedText(_actualSellingPriceController, actualSellingPrice);
    _setCalculatedText(
      _unitPriceController,
      quantity == null || quantity < 1 ? null : actualSellingPrice / quantity,
    );
    _setCalculatedText(
      _mrpUnitPriceController,
      mrp == null || mrp < 0 || quantity == null || quantity < 1
          ? null
          : mrp / quantity,
    );
  }

  Future<void> _pickProductImage(String slot) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (slot == 'front') {
        _frontImage = image;
        _frontImageBytes = bytes;
      } else if (slot == 'back') {
        _backImage = image;
        _backImageBytes = bytes;
      }
    });
  }

  Future<String> _uploadProductImage(XFile? image) async {
    if (image == null) return '';
    return CloudinaryUploadService.uploadImage(
      image: image,
      uploadPreset: CloudinaryUploadService.productPreset,
    );
  }

  Future<void> _submitProduct() async {
    _recalculatePrices();
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_sellerId == null) return;
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a front product image.')),
      );
      return;
    }
    final sellerPrice = _number(_sellerPriceController.text);
    final margin = _number(_marginController.text);
    final mrp = _number(_mrpController.text);
    final moq = int.tryParse(_minOrderController.text.trim());
    final quantity = int.tryParse(_howManyInUnitController.text.trim());
    if (sellerPrice == null ||
        sellerPrice < 0 ||
        margin == null ||
        margin < 0 ||
        margin > 100 ||
        mrp == null ||
        mrp < 0 ||
        moq == null ||
        moq < 1 ||
        quantity == null ||
        quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid prices, a margin from 0 to 100%, and positive quantities.',
          ),
        ),
      );
      return;
    }
    // Keep the stored values unrounded so the Firestore rule can verify the
    // formula exactly. The UI displays these values rounded to two decimals.
    final actualSellingPrice = sellerPrice * (1 + margin / 100);
    final unitPrice = actualSellingPrice / quantity;
    final mrpUnitPrice = mrp / quantity;
    if (mrp < actualSellingPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MRP must be at least the actual selling price.'),
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
        throw StateError('Choose an approved seller.');
      }
      final frontImageUrl = await _uploadProductImage(_frontImage);
      final backImageUrl = await _uploadProductImage(_backImage);
      await FirebaseFirestore.instance.collection('products').doc().set({
        'productName': _nameController.text.trim(),
        'category': _selectedCategory,
        'sellerId': seller.id,
        'sellerName':
            '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim(),
        'sellerShopName': (profile['shopName'] ?? '').toString(),
        'sellerShopAddress': (profile['shopAddress'] ?? '').toString(),
        // Seller base price + Admin margin + calculated buyer prices.
        'sellerSellingPrice': sellerPrice,
        'marginPercent': margin,
        'actualSellingPrice': actualSellingPrice,
        // Existing catalog, cart and estimate screens continue to use this.
        'sellingPrice': actualSellingPrice,
        'mrp': mrp,
        'unitPrice': unitPrice,
        'mrpUnitPrice': mrpUnitPrice,
        'minOrderQuantity': moq,
        'howManyProductsInUnit': quantity,
        'unitTypes': _unitTypeController.text.trim(),
        'currentRating': _currentRatingController.text.trim(),
        'warranty': _warrantyController.text.trim(),
        'description': _descController.text.trim(),
        'frontImage': frontImageUrl,
        'backImage': backImageUrl,
        // Kept for compatibility with existing Firestore product rules.
        'sideImage': '',
        // Buyer reviews keep their own numeric values in the reviews subcollection.
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
    } on CloudinaryUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
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
          .where((doc) => doc.data()['accountStatus'] == 'approved')
          .toList();
      if (sellers.isEmpty) {
        return const Text('Approve a Seller account before adding products.');
      }
      final selected = sellers.any((doc) => doc.id == _sellerId)
          ? _sellerId
          : null;
      return DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: _inputDecoration('Assign Seller'),
        items: sellers
            .map(
              (doc) => DropdownMenuItem<String>(
                value: doc.id,
                child: Text(
                  '${doc.data()['shopName'] ?? ''} — '
                  '${doc.data()['firstName'] ?? ''} '
                  '(${doc.data()['email'] ?? ''})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: _saving
            ? null
            : (value) => setState(() => _sellerId = value),
        validator: (value) =>
            value == null ? 'Select an approved seller' : null,
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildImagePicker(
                    label: 'Front View *',
                    bytes: _frontImageBytes,
                    onTap: _saving ? null : () => _pickProductImage('front'),
                  ),
                  const SizedBox(width: 8),
                  _buildImagePicker(
                    label: 'Back View',
                    bytes: _backImageBytes,
                    onTap: _saving ? null : () => _pickProductImage('back'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Front image is required. Tap an image box to choose or replace it.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _sellerField(),
              const SizedBox(height: 16),
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
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter product name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryOptions.contains(_selectedCategory)
                    ? _selectedCategory
                    : null,
                validator: (value) =>
                    value == null ? 'Add a category first' : null,
                decoration: _inputDecoration('Category'),
                items: _categoryOptions
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
              ),
              const SizedBox(height: 20),
              const Text(
                'Pricing Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellerPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Seller Selling Price (₹)',
                        hint: '1000',
                      ),
                      validator: (value) {
                        final price = _number(value ?? '');
                        return price == null || !price.isFinite || price < 0
                            ? 'Enter a valid price'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _marginController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Admin Margin (%)',
                        hint: '10 or 10%',
                      ),
                      validator: (value) {
                        final margin = _number(value ?? '');
                        return margin == null ||
                                !margin.isFinite ||
                                margin < 0 ||
                                margin > 100
                            ? 'Use 0 to 100%'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _actualSellingPriceController,
                readOnly: true,
                decoration: _inputDecoration(
                  'Actual Selling Price (₹)',
                  hint: 'Calculated automatically',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('MRP (₹)', hint: '1800'),
                      validator: (value) {
                        final mrp = _number(value ?? '');
                        return mrp == null || !mrp.isFinite || mrp < 0
                            ? 'Enter a valid MRP'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitPriceController,
                      readOnly: true,
                      decoration: _inputDecoration(
                        'Unit Price (₹)',
                        hint: 'Calculated automatically',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mrpUnitPriceController,
                readOnly: true,
                decoration: _inputDecoration(
                  'MRP Unit Price (₹)',
                  hint: 'Calculated automatically',
                ),
              ),
              const SizedBox(height: 20),
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
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        'Min Order Quantity',
                        hint: '50',
                      ),
                      validator: (value) {
                        final number = int.tryParse(value?.trim() ?? '');
                        if (number == null || number <= 0) {
                          return 'Enter a positive whole number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _howManyInUnitController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Qty in Unit', hint: '10'),
                      validator: (value) {
                        final number = int.tryParse(value?.trim() ?? '');
                        if (number == null || number <= 0) {
                          return 'Enter a positive whole number';
                        }
                        return null;
                      },
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currentRatingController,
                      decoration: _inputDecoration(
                        'Current Rating',
                        hint: 'e.g. Top Rated / 4.5 Stars',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
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
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 28),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

  Widget _buildImagePicker({
    required String label,
    required Uint8List? bytes,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: bytes == null
                ? Column(
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
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes, fit: BoxFit.cover),
                      const Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: Color(0xCC0052FF),
                            child: Icon(
                              Icons.edit,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
