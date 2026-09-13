import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'catalog_support.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  const EditProductScreen({super.key, required this.productId});
  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _form = GlobalKey<FormState>();
  static const _labels = <String, String>{
    'sellingPrice': 'Selling Price (₹)',
    'mrp': 'MRP (₹)',
    'unitPrice': 'Unit Price (₹)',
    'mrpUnitPrice': 'MRP Unit Price (₹)',
    'minOrderQuantity': 'Minimum Order Quantity',
    'howManyProductsInUnit': 'Quantity in 1 Unit',
    'unitTypes': 'Unit Type',
    'warranty': 'Warranty',
    'description': 'Description',
  };
  static const _prices = ['sellingPrice', 'mrp', 'unitPrice', 'mrpUnitPrice'];
  static const _quantities = ['minOrderQuantity', 'howManyProductsInUnit'];
  final _fields = <String, TextEditingController>{};
  Map<String, dynamic>? _original;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    for (final key in _labels.keys) {
      _fields[key] = TextEditingController();
    }
    _load();
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
      if (!mounted) return;
      final data = doc.data();
      if (data == null ||
          data['sellerId'] != FirebaseAuth.instance.currentUser?.uid) {
        setState(
          () => _error =
              'This product is unavailable or belongs to another seller.',
        );
        return;
      }
      _original = data;
      for (final key in _labels.keys) {
        _fields[key]!.text = _prices.contains(key)
            ? catalogNumber(data[key]).toString()
            : (data[key] ?? '').toString();
      }
    } catch (e) {
      if (mounted) setState(() => _error = catalogError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validate(String key, String? text) {
    final value = (text ?? '').trim();
    if (_prices.contains(key)) {
      final number = double.tryParse(value);
      if (number == null || !number.isFinite || number < 0) {
        return 'Enter a non-negative number';
      }
    } else if (_quantities.contains(key)) {
      final number = int.tryParse(value);
      if (number == null || number < 1) return 'Enter a positive whole number';
    } else if (key.endsWith('Image') && value.isNotEmpty) {
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'Use a valid HTTPS image URL';
      }
    }
    if (value.length > 5000) return 'Maximum 5000 characters';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final update = <String, dynamic>{};
    for (final key in _labels.keys) {
      final value = _fields[key]!.text.trim();
      update[key] = _prices.contains(key)
          ? double.parse(value)
          : _quantities.contains(key)
          ? int.parse(value)
          : value;
    }
    if (update['mrp'] < update['sellingPrice'] ||
        update['mrpUnitPrice'] < update['unitPrice']) {
      setState(
        () => _error =
            'MRP must be at least its corresponding selling/unit price.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');
      // Update only editable fields; preserve current stock and Admin decisions.
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
            ...update,
            'updatedBy': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = catalogError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FA),
    appBar: AppBar(
      title: const Text('Edit Product'),
      backgroundColor: Colors.white,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _original == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Product unavailable'),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Product ID: ${widget.productId}'),
                  Text('Product Name: ${_original!['productName']}'),
                  Text('Category: ${_original!['category']}'),
                  const SizedBox(height: 16),
                  ..._labels.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _fields[entry.key],
                        enabled: !_saving,
                        keyboardType:
                            _prices.contains(entry.key) ||
                                _quantities.contains(entry.key)
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        maxLines: entry.key == 'description' ? 4 : 1,
                        decoration: InputDecoration(
                          labelText: entry.value,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) => _validate(entry.key, value),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
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
