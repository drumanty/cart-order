import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_upload_service.dart';

class UploadQueryScreen extends StatefulWidget {
  const UploadQueryScreen({super.key});
  @override
  State<UploadQueryScreen> createState() => _UploadQueryScreenState();
}

class _UploadQueryScreenState extends State<UploadQueryScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  int _quantity = 1;
  bool _submitting = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _priceError(String? text) {
    final value = double.tryParse((text ?? '').trim());
    if (value == null || !value.isFinite || value < 0 || value > 1000000000) {
      return 'Enter a valid price (0–1 billion)';
    }
    return null;
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  Future<String> _uploadSelectedImage() async {
    final image = _selectedImage;
    if (image == null) return '';
    return CloudinaryUploadService.uploadImage(
      image: image,
      uploadPreset: CloudinaryUploadService.productPreset,
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _submitQuery() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in as a Buyer.')),
          );
        }
        return;
      }
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (profile.data()?['userType'] != 'Buyer' ||
          profile.data()?['accountStatus'] != 'approved') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This function is only for approved Buyers.'),
            ),
          );
        }
        return;
      }
      final imageUrl = await _uploadSelectedImage();

      await FirebaseFirestore.instance.collection('product_queries').add({
        'buyerId': user.uid,
        'buyerEmail': user.email ?? '',
        'buyerName':
            '${profile.data()?['firstName'] ?? ''} ${profile.data()?['lastName'] ?? ''}'
                .trim(),
        'mobileNumber': (profile.data()?['mobileNumber'] ?? '').toString(),
        'productName': _productNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'minPrice': double.parse(_minPriceController.text.trim()),
        'maxPrice': double.parse(_maxPriceController.text.trim()),
        'quantity': _quantity,
        'imageUrl': imageUrl,
        'status': 'submitted',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Query submitted'),
          content: const Text(
            'Our support team will contact you within 72 hours.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() => _submitting = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } on CloudinaryUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'Submission not permitted. Check Buyer approval and publish the product_queries rules.'
          : 'Could not save your query (${error.code}). Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit your query. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Upload Product Query'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Upload Header
                  _buildSectionHeader('Product Image'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _submitting ? null : _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedImageBytes != null)
                            Image.memory(
                              _selectedImageBytes!,
                              height: 60,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    size: 32,
                                  ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEBF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_a_photo_outlined,
                                color: Color(0xFF0052FF),
                                size: 24,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedImageBytes == null
                                ? 'Select Product Image (Optional)'
                                : 'Image selected — uploaded when submitted',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Product Name
                  _buildSectionHeader('Product Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    enabled: !_submitting,
                    controller: _productNameController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter product name';
                      }
                      if (value.trim().length > 300) {
                        return 'Maximum 300 characters';
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(
                      'e.g., Modular Switch Panel',
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Price Range (Min & Max)
                  _buildSectionHeader('Price Range'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          enabled: !_submitting,
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration('Min Price (₹)'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter min price';
                            }
                            return _priceError(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          enabled: !_submitting,
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration('Max Price (₹)'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter max price';
                            }
                            final error = _priceError(value);
                            if (error != null) return error;
                            if (_minPriceController.text.isNotEmpty) {
                              final min =
                                  double.tryParse(_minPriceController.text) ??
                                  0;
                              final max = double.tryParse(value) ?? 0;
                              if (max < min) {
                                return 'Must be ≥ Min';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Quantity
                  _buildSectionHeader('Required Quantity'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Units Needed',
                          style: TextStyle(fontSize: 13),
                        ),
                        Row(
                          children: [
                            _buildQuantityBtn(
                              icon: Icons.remove,
                              onPressed: () {
                                if (!_submitting && _quantity > 1) {
                                  setState(() => _quantity--);
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14.0,
                              ),
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildQuantityBtn(
                              icon: Icons.add,
                              onPressed: () {
                                if (!_submitting && _quantity < 1000000) {
                                  setState(() => _quantity++);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description
                  _buildSectionHeader('Description'),
                  const SizedBox(height: 8),
                  TextFormField(
                    enabled: !_submitting,
                    controller: _descriptionController,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please provide a description';
                      }
                      if (value.trim().length > 5000) {
                        return 'Maximum 5000 characters';
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(
                      'Enter product details, specifications...',
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitQuery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _submitting ? 'Submitting…' : 'Submit Product Query',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildQuantityBtn({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: Colors.black87),
        onPressed: onPressed,
      ),
    );
  }
}
