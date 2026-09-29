import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_navigation.dart';
import 'cloudinary_upload_service.dart';
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
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  String _userType = 'Buyer';
  String? _businessCategory;
  bool _isTermsAccepted = false;
  bool _hasReadTermsAndPrivacy = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  XFile? _profileImage;
  Uint8List? _profileImageBytes;
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
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profileImage = image;
        _profileImageBytes = bytes;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not select the photo.')),
        );
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (_isLoading) return;
    if (!_hasReadTermsAndPrivacy) {
      showAuthError(
        context,
        const FormatException(
          'Please read the Terms & Conditions and Privacy Policy to the end.',
        ),
      );
      return;
    }
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
        final photoUrl = _profileImage == null
            ? null
            : await CloudinaryUploadService.uploadImage(
                image: _profileImage!,
                uploadPreset: CloudinaryUploadService.profilePreset,
              );
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
              'city': _cityController.text.trim(),
              'state': _stateController.text.trim(),
              'pincode': _pincodeController.text.trim(),
              'photoUrl': photoUrl,
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
    } on CloudinaryUploadException catch (error) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
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

  Future<void> _readTermsAndPrivacy() async {
    var reachedBottom = false;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.92,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Terms & Privacy',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          final atBottom =
                              notification.metrics.maxScrollExtent > 0 &&
                              notification.metrics.pixels >=
                                  notification.metrics.maxScrollExtent - 16;
                          if (atBottom && !reachedBottom) {
                            setSheetState(() => reachedBottom = true);
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cart & Order — Terms & Conditions',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'By creating an account, you confirm that the information you provide is accurate and that you are authorised to represent your business.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '1. Account approval',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Buyer and Seller accounts are subject to admin approval. We may reject, suspend or deactivate an account if information is incomplete, inaccurate, misleading or used unlawfully.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '2. Product information and estimates',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Product images, prices, stock, package quantities and descriptions may change. An enquiry, cart item or estimate request is not a confirmed purchase order until it is reviewed and confirmed by the relevant business.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '3. Responsible use',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Do not misuse the app, submit false enquiries, attempt unauthorised access, upload illegal content or interfere with another user’s account. We may restrict access to protect the platform and its users.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '4. Communication',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You agree that the support team or a seller may contact you about your account, enquiry, sample request, estimate or product-related service using the contact details you provide.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'We collect account details such as your name, business information, email address, mobile number, address and optional profile photo. We also keep operational data such as product searches, enquiries, cart activity, estimate requests and account approval status.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '5. How we use your information',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your information is used to create and approve accounts, display business details where needed, process enquiries and requests, provide support, improve the app and help prevent abuse or fraud.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '6. Sharing and security',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We share only the information needed to handle a business request, for example buyer contact details with the responsible support team or seller. We use technical safeguards, but no online service can guarantee absolute security.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '7. Your choices',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You may request correction of inaccurate account information or ask questions about your data by contacting the app administrator. Some information may need to be retained where required for legitimate business, security or legal reasons.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'By selecting the button below, you confirm that you have read and agree to these Terms & Conditions and Privacy Policy.',
                                style: TextStyle(
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: FilledButton.icon(
                        onPressed: reachedBottom
                            ? () => Navigator.pop(context, true)
                            : null,
                        icon: Icon(
                          reachedBottom
                              ? Icons.check_circle_outline
                              : Icons.south_rounded,
                        ),
                        label: Text(
                          reachedBottom
                              ? 'I Have Read & Accept'
                              : 'Scroll to the Bottom',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0052FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (accepted == true && mounted) {
      setState(() {
        _hasReadTermsAndPrivacy = true;
        _isTermsAccepted = true;
      });
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
                              CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFFEBF2FF),
                                backgroundImage: _profileImageBytes == null
                                    ? null
                                    : MemoryImage(_profileImageBytes!),
                                child: _profileImageBytes == null
                                    ? const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 32,
                                        color: Color(0xFF0052FF),
                                      )
                                    : null,
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
                        controller: _cityController,
                        hintText: 'City',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        controller: _stateController,
                        hintText: 'State',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 14),
                      _buildInputField(
                        controller: _pincodeController,
                        hintText: 'Pincode',
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
                      OutlinedButton.icon(
                        onPressed: _readTermsAndPrivacy,
                        icon: Icon(
                          _hasReadTermsAndPrivacy
                              ? Icons.check_circle_outline
                              : Icons.article_outlined,
                          color: const Color(0xFF0052FF),
                        ),
                        label: Text(
                          _hasReadTermsAndPrivacy
                              ? 'Terms & Privacy Read'
                              : 'Read Terms & Privacy First',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(color: Color(0xFF0052FF)),
                          foregroundColor: const Color(0xFF0052FF),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                              onChanged: !_hasReadTermsAndPrivacy
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _isTermsAccepted = value ?? false,
                                      );
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _hasReadTermsAndPrivacy
                                  ? 'I agree to the Terms & Conditions and Privacy Policy.'
                                  : 'Read and scroll to the bottom of the Terms & Privacy first.',
                              style: TextStyle(
                                color: _hasReadTermsAndPrivacy
                                    ? Colors.black
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!_hasReadTermsAndPrivacy)
                        const Text(
                          'You must read and scroll to the end before creating an account.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        )
                      else if (!_isTermsAccepted)
                        const Text(
                          'Please accept the Terms & Conditions to create an account.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _hasReadTermsAndPrivacy && _isTermsAccepted
                              ? _handleSignUp
                              : null,
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
                            _hasReadTermsAndPrivacy && _isTermsAccepted
                                ? 'Create Account'
                                : 'Read Terms & Privacy First',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: _hasReadTermsAndPrivacy && _isTermsAccepted
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
        return FormField<String>(
          key: ValueKey<String?>(selectedValue),
          initialValue: selectedValue,
          validator: (value) => value == null || !categories.contains(value)
              ? 'Please select a Business Category'
              : null,
          builder: (field) {
            final screenSize = MediaQuery.of(context).size;
            final menuWidth = (screenSize.width * 0.60)
                .clamp(180.0, 360.0)
                .toDouble();
            return PopupMenuButton<String>(
              enabled: categories.isNotEmpty && !_isLoading,
              tooltip: 'Choose business category',
              position: PopupMenuPosition.under,
              offset: Offset(screenSize.width, 6),
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: BoxConstraints(
                minWidth: menuWidth,
                maxWidth: menuWidth,
                maxHeight: screenSize.height * 0.45,
              ),
              onSelected: (value) {
                field.didChange(value);
                setState(() => _businessCategory = value);
              },
              itemBuilder: (_) => categories.map((category) {
                final isSelected = category == selectedValue;
                return PopupMenuItem<String>(
                  value: category,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            category,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? const Color(0xFF0052FF)
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF0052FF),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Business Category',
                  errorText: field.errorText,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.category_outlined,
                    color: Color(0xFF0052FF),
                    size: 20,
                  ),
                  suffixIcon: const Icon(
                    Icons.expand_more_rounded,
                    color: Color(0xFF0052FF),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                child: Text(
                  selectedValue ??
                      (categories.isEmpty
                          ? 'No categories available'
                          : 'Select category'),
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedValue == null
                        ? Colors.grey.shade500
                        : Colors.black87,
                  ),
                ),
              ),
            );
          },
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
          if (controller == _emailController) {
            final email = text.trim().toLowerCase();
            if (!email.endsWith('@gmail.com') ||
                email.length <= '@gmail.com'.length) {
              return 'Enter an email such as name\@gmail.com';
            }
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
