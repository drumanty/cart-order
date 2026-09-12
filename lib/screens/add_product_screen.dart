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

  void _submitProduct() {
    if (_formKey.currentState!.validate()) {
      final newProduct = {
        'id':
            'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'productName': _nameController.text.trim(),
        'category': _selectedCategory,
        'unitPrice': '₹ ${_unitPriceController.text.trim()}',
        'mrp': '₹ ${_mrpController.text.trim()}',
        'sellingPrice': '₹ ${_sellingPriceController.text.trim()}',
        'mrpUnitPrice': '₹ ${_mrpUnitPriceController.text.trim()}',
        'minOrderAmount': '₹ ${_minOrderController.text.trim()}',
        'howManyProductsInUnit': _howManyInUnitController.text.trim(),
        'unitTypes': _unitTypeController.text.trim(),
        'ratings': 5.0,
        'warranty': _warrantyController.text.trim().isEmpty
            ? '12 Months Warranty'
            : _warrantyController.text.trim(),
        'description': _descController.text.trim(),
        'frontImage': 'https://picsum.photos/id/100/300/300',
        'backImage': 'https://picsum.photos/id/101/300/300',
        'sideImage': 'https://picsum.photos/id/102/300/300',
        'status': 'Approved',
      };

      Navigator.pop(context, newProduct);
    }
  }

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
                value: _selectedCategory,
                decoration: _inputDecoration('Category'),
                items: widget.categories
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
                        hint: '50 Units',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _howManyInUnitController,
                      decoration: _inputDecoration(
                        'Qty in Unit',
                        hint: '10 Rolls',
                      ),
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
                  onPressed: _submitProduct,
                  child: const Text(
                    'Save Product',
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
