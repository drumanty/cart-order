import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'catalog_support.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;

  const EditProductScreen({super.key, required this.productId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerPriceController = TextEditingController();
  final _marginController = TextEditingController();
  final _actualPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _mrpUnitPriceController = TextEditingController();
  final _minimumController = TextEditingController();
  final _quantityInUnitController = TextEditingController();
  final _unitTypeController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _frontImageController = TextEditingController();
  final _backImageController = TextEditingController();
  final _sideImageController = TextEditingController();

  Map<String, dynamic>? _product;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _sellerPriceController,
      _mrpController,
      _quantityInUnitController,
    ]) {
      controller.addListener(_recalculatePrices);
    }
    _load();
  }

  double? _number(String value) => double.tryParse(
    value.trim().replaceAll('₹', '').replaceAll('%', '').replaceAll(',', ''),
  );

  void _setCalculatedText(TextEditingController controller, double? value) {
    final text = value == null ? '' : value.toStringAsFixed(2);
    if (controller.text != text) controller.text = text;
  }

  void _recalculatePrices() {
    final sellerPrice = _number(_sellerPriceController.text);
    final margin = _number(_marginController.text);
    final mrp = _number(_mrpController.text);
    final quantity = int.tryParse(_quantityInUnitController.text.trim());
    if (sellerPrice == null ||
        sellerPrice < 0 ||
        margin == null ||
        margin < 0) {
      _setCalculatedText(_actualPriceController, null);
      _setCalculatedText(_unitPriceController, null);
      _setCalculatedText(_mrpUnitPriceController, null);
      return;
    }

    final actual = sellerPrice * (1 + margin / 100);
    _setCalculatedText(_actualPriceController, actual);
    _setCalculatedText(
      _unitPriceController,
      quantity == null || quantity < 1 ? null : actual / quantity,
    );
    _setCalculatedText(
      _mrpUnitPriceController,
      mrp == null || mrp < 0 || quantity == null || quantity < 1
          ? null
          : mrp / quantity,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();
      final data = doc.data();
      if (data == null ||
          data['sellerId'] != FirebaseAuth.instance.currentUser?.uid) {
        throw StateError(
          'This product is unavailable or belongs to another seller.',
        );
      }
      if (data['sellerSellingPrice'] is! num || data['marginPercent'] is! num) {
        throw StateError(
          'This product needs margin configuration from an Admin before it can be edited.',
        );
      }

      _product = data;
      _sellerPriceController.text = catalogNumber(
        data['sellerSellingPrice'],
      ).toString();
      _marginController.text = catalogNumber(data['marginPercent']).toString();
      _mrpController.text = catalogNumber(data['mrp']).toString();
      _minimumController.text = (data['minOrderQuantity'] ?? '').toString();
      _quantityInUnitController.text = (data['howManyProductsInUnit'] ?? '')
          .toString();
      _unitTypeController.text = (data['unitTypes'] ?? '').toString();
      _warrantyController.text = (data['warranty'] ?? '').toString();
      _descriptionController.text = (data['description'] ?? '').toString();
      _frontImageController.text = (data['frontImage'] ?? '').toString();
      _backImageController.text = (data['backImage'] ?? '').toString();
      _sideImageController.text = (data['sideImage'] ?? '').toString();
      _recalculatePrices();
    } catch (error) {
      _error = error is StateError
          ? error.message.toString()
          : catalogError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final sellerPrice = _number(_sellerPriceController.text);
    final margin = _number(_marginController.text);
    final mrp = _number(_mrpController.text);
    final minimum = int.tryParse(_minimumController.text.trim());
    final quantity = int.tryParse(_quantityInUnitController.text.trim());
    if (sellerPrice == null ||
        sellerPrice < 0 ||
        margin == null ||
        margin < 0 ||
        mrp == null ||
        mrp < 0 ||
        minimum == null ||
        minimum < 1 ||
        quantity == null ||
        quantity < 1) {
      setState(() => _error = 'Enter valid prices and positive quantities.');
      return;
    }

    final actual = sellerPrice * (1 + margin / 100);
    if (mrp < actual) {
      setState(() => _error = 'MRP must be at least the actual selling price.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out.');

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
            // Sellers may change their base price. The margin remains Admin-only.
            'sellerSellingPrice': sellerPrice,
            'actualSellingPrice': actual,
            'sellingPrice': actual,
            'mrp': mrp,
            'unitPrice': actual / quantity,
            'mrpUnitPrice': mrp / quantity,
            'minOrderQuantity': minimum,
            'howManyProductsInUnit': quantity,
            'unitTypes': _unitTypeController.text.trim(),
            'warranty': _warrantyController.text.trim(),
            'description': _descriptionController.text.trim(),
            'frontImage': _frontImageController.text.trim(),
            'backImage': _backImageController.text.trim(),
            'sideImage': _sideImageController.text.trim(),
            'updatedBy': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = catalogError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _numberValidator(String? value) {
    final number = _number(value ?? '');
    return number == null || !number.isFinite || number < 0
        ? 'Enter a valid non-negative number'
        : null;
  }

  String? _quantityValidator(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 1
        ? 'Enter a positive whole number'
        : null;
  }

  String? _imageValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri == null || uri.scheme != 'https' || uri.host.isEmpty
        ? 'Use a valid HTTPS URL'
        : null;
  }

  @override
  void dispose() {
    for (final controller in [
      _sellerPriceController,
      _marginController,
      _actualPriceController,
      _mrpController,
      _unitPriceController,
      _mrpUnitPriceController,
      _minimumController,
      _quantityInUnitController,
      _unitTypeController,
      _warrantyController,
      _descriptionController,
      _frontImageController,
      _backImageController,
      _sideImageController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Product unavailable',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product: ${_product!['productName']}'),
                    Text('Category: ${_product!['category']}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Pricing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _sellerPriceController,
                      'Your Selling Price (₹)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _numberValidator,
                    ),
                    _field(
                      _marginController,
                      'Admin Margin (%)',
                      readOnly: true,
                    ),
                    _field(
                      _actualPriceController,
                      'Actual Selling Price (₹)',
                      readOnly: true,
                    ),
                    _field(
                      _mrpController,
                      'MRP (₹)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _numberValidator,
                    ),
                    _field(
                      _unitPriceController,
                      'Unit Price (₹)',
                      readOnly: true,
                    ),
                    _field(
                      _mrpUnitPriceController,
                      'MRP Unit Price (₹)',
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Packaging & Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _minimumController,
                      'Minimum Order Quantity',
                      keyboardType: TextInputType.number,
                      validator: _quantityValidator,
                    ),
                    _field(
                      _quantityInUnitController,
                      'Quantity in 1 Unit',
                      keyboardType: TextInputType.number,
                      validator: _quantityValidator,
                    ),
                    _field(
                      _unitTypeController,
                      'Unit Type',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    _field(
                      _warrantyController,
                      'Warranty',
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    _field(
                      _descriptionController,
                      'Description',
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    _field(
                      _frontImageController,
                      'Front Image HTTPS URL',
                      validator: _imageValidator,
                    ),
                    _field(
                      _backImageController,
                      'Back Image HTTPS URL',
                      validator: _imageValidator,
                    ),
                    _field(
                      _sideImageController,
                      'Side Image HTTPS URL',
                      validator: _imageValidator,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        maxLines: maxLines,
        enabled: !_saving,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: readOnly ? const Color(0xFFF1F3F6) : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
