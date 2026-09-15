import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_navigation.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _gstPanController = TextEditingController();
  final _shopAddressController = TextEditingController();

  String _userType = 'Buyer';
  String? _businessCategory;

  bool _isTermsAccepted = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shopNameController.dispose();
    _gstPanController.dispose();
    _shopAddressController.dispose();
    super.dispose();
  }

  void _pickImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Photo uploads will be enabled after image hosting is configured.',
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (_isLoading) return;

    if (!_isTermsAccepted) {
      showAuthError(
        context,
        const FormatException('Please accept the Terms & Conditions.'),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_businessCategory == null || _businessCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Business Category.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      UserCredential credential;

      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;

        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final user = credential.user;

      if (user == null) {
        throw StateError('No authenticated user was returned.');
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final existingProfile = await userRef.get(
        const GetOptions(source: Source.server),
      );

      if (!existingProfile.exists) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final latestProfile = await transaction.get(userRef);

          if (!latestProfile.exists) {
            transaction.set(userRef, {
              'uid': user.uid,
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'email': user.email ?? email,
              'mobileNumber': _mobileController.text.trim(),
              'userType': _userType,
              'shopName': _shopNameController.text.trim(),
              'businessCategory': _businessCategory!.trim(),
              'gstPanNumber': _gstPanController.text.trim(),
              'shopAddress': _shopAddressController.text.trim(),
              'photoUrl': null,
              'photoPath': null,
              'termsAccepted': true,
              'termsAcceptedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'accountStatus': 'pending',
            });
          }
        });
      }

      if (!mounted) return;

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingProfile.exists
                ? 'Account already exists. Please log in; Admin approval is required.'
                : 'Account submitted. Please wait for Admin approval before logging in.',
          ),
        ),
      );

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        showAuthError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.maybePop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Join us and start exploring\nbest quality products',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 130,
                            height: 130,
                            padding: const EdgeInsets.all(4),
                            child: Image.asset(
                              'assets/model.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              const CircleAvatar(
                                radius: 42,
                                backgroundColor: Color(0xFFEBF2FF),
                                child: Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 32,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0052FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Select Account Type:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                'Buyer',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: _userType == 'Buyer',
                              activeColor: const Color(0xFF0052FF),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) {
                                if (value == true) {
                                  setState(() => _userType = 'Buyer');
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                'Seller',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: _userType == 'Seller',
                              activeColor: const Color(0xFF0052FF),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) {
                                if (value == true) {
                                  setState(() => _userType = 'Seller');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _firstNameController,
                              hintText: 'First Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _lastNameController,
                              hintText: 'Last Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _shopNameController,
                        hintText: 'Shop Name',
                        icon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 14),

                      _buildBusinessCategoryDropdown(),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _gstPanController,
                        hintText: 'GSTIN / PAN Card',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _shopAddressController,
                        hintText: 'Shop Address',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _emailController,
                        hintText: 'Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _buildMobileField(),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _passwordController,
                        hintText: 'Create Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isTermsAccepted,
                              activeColor: const Color(0xFF0052FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) {
                                setState(
                                  () => _isTermsAccepted = value ?? false,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: Color(0xFF0052FF),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: Color(0xFF0052FF),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (!_isTermsAccepted)
                        const Text(
                          'Please select Terms & Conditions to create an account.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isTermsAccepted ? _handleSignUp : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0052FF),
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isTermsAccepted
                                ? 'Create Account'
                                : 'Please select Terms & Conditions',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: _isTermsAccepted
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: Color(0xFF0052FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBusinessCategoryDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('business_categories')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Text(
              'Could not load Business Categories.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                SizedBox(width: 16),
                Icon(Icons.category_outlined, color: Colors.grey),
                SizedBox(width: 12),
                Expanded(child: Text('Loading Business Categories...')),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
              ],
            ),
          );
        }

        final categories =
            snapshot.data!.docs
                .map((doc) => (doc.data()['name'] ?? '').toString().trim())
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        final selectedValue = categories.contains(_businessCategory)
            ? _businessCategory
            : null;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedValue,
            isExpanded: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please select a Business Category';
              }
              return null;
            },
            icon: const Icon(Icons.keyboard_arrow_down),
            decoration: InputDecoration(
              hintText: categories.isEmpty
                  ? 'No Business Categories available'
                  : 'Select Business Category',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(
                Icons.category_outlined,
                color: Colors.grey.shade500,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            items: categories
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: categories.isEmpty
                ? null
                : (value) {
                    setState(() => _businessCategory = value);
                  },
          ),
        );
      },
    );
  }

  Widget _buildMobileField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: _mobileController,
        keyboardType: TextInputType.phone,
        validator: (value) {
          final mobile = (value ?? '').trim();

          if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
            return 'Enter a valid 10-digit Indian mobile number';
          }

          return null;
        },
        decoration: InputDecoration(
          hintText: 'Mobile Number',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              Icon(Icons.phone_outlined, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 8),
              const Text(
                '+91',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: (value) {
          final text = value ?? '';

          if (text.trim().isEmpty) {
            return 'Required';
          }

          if (controller == _emailController &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text.trim())) {
            return 'Enter a valid email address';
          }

          if (controller == _passwordController && text.length < 6) {
            return 'Use at least 6 characters';
          }

          if (controller == _confirmPasswordController &&
              text != _passwordController.text) {
            return 'Passwords do not match';
          }

          return null;
        },
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
