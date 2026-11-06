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

  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  // Quantity unit types
  final List<String> _unitTypes = [
    'Pcs',
    'Dozen',
    'Gross',
    'Coil',
    'MTR',
    'Box',
    'Kg',
    'LTR',
    'Grm',
  ];

  String _selectedUnitType = 'Pcs';

  bool _submitting = false;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  // Price validation
  String? _priceError(String? text) {
    final value = double.tryParse((text ?? '').trim());

    if (value == null || !value.isFinite || value < 0 || value > 1000000000) {
      return 'Enter a valid price (0–1 billion)';
    }

    return null;
  }

  // Quantity validation
  String? _quantityError(String? text) {
    final quantity = int.tryParse((text ?? '').trim());

    if (quantity == null || quantity < 1) {
      return 'Enter valid quantity';
    }

    if (quantity > 1000000) {
      return 'Maximum 1000000';
    }

    return null;
  }

  // Pick product image
  Future<void> _pickImage() async {
    if (_submitting) return;

    try {
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
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select image. Please try again.'),
        ),
      );
    }
  }

  // Upload image to Cloudinary
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
    _quantityController.dispose();

    super.dispose();
  }

  // Submit product query
  Future<void> _submitQuery() async {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

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

      // Verify Buyer profile
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final profileData = profile.data();

      if (profileData == null ||
          profileData['userType'] != 'Buyer' ||
          profileData['accountStatus'] != 'approved') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This function is only for approved Buyers.'),
            ),
          );
        }
        return;
      }

      // Upload image if selected
      final imageUrl = await _uploadSelectedImage();

      // Parse form values
      final minPrice = double.parse(_minPriceController.text.trim());

      final maxPrice = double.parse(_maxPriceController.text.trim());

      final quantity = int.parse(_quantityController.text.trim());

      // Save query to Firestore
      await FirebaseFirestore.instance.collection('product_queries').add({
        'buyerId': user.uid,
        'buyerEmail': user.email ?? '',
        'buyerName':
            '${profileData['firstName'] ?? ''} '
                    '${profileData['lastName'] ?? ''}'
                .trim(),
        'mobileNumber': (profileData['mobileNumber'] ?? '').toString(),

        'productName': _productNameController.text.trim(),
        'description': _descriptionController.text.trim(),

        'minPrice': minPrice,
        'maxPrice': maxPrice,

        // Updated quantity information
        'quantity': quantity,
        'unitType': _selectedUnitType,

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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context);
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
          ? 'Submission not permitted. Check Buyer approval and product_queries Firestore rules.'
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
      if (mounted) {
        setState(() => _submitting = false);
      }
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
                  // Product Image
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
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.broken_image_outlined,
                                  size: 32,
                                );
                              },
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

                  // Price Range
                  _buildSectionHeader('Price Range'),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          enabled: !_submitting,
                          controller: _minPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),

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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),

                          decoration: _buildInputDecoration('Max Price (₹)'),

                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter max price';
                            }

                            final error = _priceError(value);

                            if (error != null) return error;

                            if (_minPriceController.text.isNotEmpty) {
                              final min =
                                  double.tryParse(
                                    _minPriceController.text.trim(),
                                  ) ??
                                  0;

                              final max = double.tryParse(value.trim()) ?? 0;

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

                  // Required Quantity - Updated
                  _buildSectionHeader('Required Quantity'),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity Input
                      Expanded(
                        child: TextFormField(
                          enabled: !_submitting,
                          controller: _quantityController,
                          keyboardType: TextInputType.number,

                          decoration: _buildInputDecoration('Quantity'),

                          validator: _quantityError,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Unit Type Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnitType,
                          isExpanded: true,
                          decoration: _buildInputDecoration('Unit Type'),

                          items: _unitTypes.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(
                                unit,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),

                          onChanged: _submitting
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedUnitType = value;
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
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
                        disabledBackgroundColor: const Color(0xFF8EABF5),
                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Product Query',
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

  // Input Decoration
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

  // Section Header
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
}
