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
                                '1. About CartAndOrder',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'CartAndOrder (“App”, “Platform”, “we”, “us”, or “our”) is a B2B product catalogue platform operating in India. The Platform enables registered business users to view product information and prices made available by sellers or authorized administrators and to request or obtain product estimates.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '2. Eligibility',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You must provide accurate information and have the legal capacity to enter into an agreement under applicable Indian law. If you register on behalf of a business, you confirm that you are authorized to provide information and act on behalf of that business.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '3. Account Registration',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Certain features require registration. You may be required to provide your name, business/shop details, address, email, phone number,  photographs, and other information reasonably required to operate the Platform. You are responsible for ensuring that submitted information is accurate and current and for maintaining the confidentiality of your login credentials.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '4. Business and Product Information',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Product information may include names, descriptions, photographs, specifications, prices, and other information supplied by sellers or authorized administrators. Although reasonable efforts may be made to maintain accurate information, CartAndOrder does not guarantee that every product description, price, image, specification, stock status, or other information will always be complete, current, or error-free. Prices and availability may change without prior notice.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '5. Estimates and Enquiries',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Any estimate generated or displayed through CartAndOrder is for informational and business-planning purposes unless expressly stated otherwise. An estimate does not automatically constitute a final purchase order, contract, invoice, or binding sale agreement. Final pricing, quantity, availability, delivery arrangements, taxes, and other commercial terms may be confirmed separately between the relevant parties.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '6. No Payment Facility',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'At the current stage, CartAndOrder does not provide an integrated payment or subscription facility. If payment or other commercial transactions are arranged separately between buyers and sellers, the relevant parties are responsible for those transactions and their applicable terms.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '7. User Responsibilities',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You agree not to provide false, misleading, or fraudulent information; use another person account without authorization; upload unlawful or infringing content; attempt unauthorized access; interfere with Platform security or operation; or use the App for unlawful, fraudulent, or abusive activities.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '8. User-Uploaded Content',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Users may upload photographs or other information. You retain ownership of content that you legally own. By uploading content, you grant CartAndOrder a limited, non-exclusive permission to host, store, process, display, and use that content as reasonably necessary to provide and operate the Platform. You are responsible for ensuring uploaded content does not violate law or third-party rights.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '9. Intellectual Property',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'The CartAndOrder name, branding, logos, software, interface, design, graphics, text, and other Platform materials may be protected by applicable intellectual property laws. Product names, trademarks, logos, photographs, and other materials supplied by sellers or third parties remain the property of their respective owners.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '10. Third-Party Services',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'CartAndOrder uses third-party services including Google Firebase, Google Analytics, and Cloudinary to support Platform functionality, analytics, and media processing/storage. Such providers may process information in accordance with their applicable terms and privacy practices.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '11. Availability',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We may modify, suspend, restrict, or discontinue any part of the Platform temporarily or permanently. We do not guarantee that CartAndOrder will always be available, uninterrupted, secure, or error-free.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '12. Account Suspension or Termination',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We may suspend or terminate an account where we reasonably believe that the user has violated these Terms, engaged in fraudulent or unlawful activity, provided materially false information, or created a security, legal, or operational risk.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '13. Disclaimer',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'CartAndOrder provides the Platform on an “as available” basis. To the extent permitted by applicable law, we do not guarantee the accuracy, completeness, reliability, suitability, or availability of all product or business information. CartAndOrder does not guarantee that a buyer and seller will complete a transaction or that a listed product will remain available at a displayed price.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '14. Limitation of Liability',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'To the maximum extent permitted by applicable law, CartAndOrder and its operators shall not be responsible for indirect, incidental, consequential, or special losses arising from use of the Platform. Nothing in these Terms is intended to exclude or limit liability that cannot legally be excluded or limited under applicable Indian law.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '15. Privacy',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your use of CartAndOrder is also governed by our Privacy Policy, which explains how we collect, use, store, and protect personal and business information.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '16. Changes to These Terms',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We may update these Terms from time to time. Updated Terms may be made available through the App or other appropriate means. Continued use after an update constitutes acceptance of the revised Terms, to the extent permitted by law.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '17. Governing Law',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'These Terms shall be governed by and interpreted in accordance with the laws of India. Any dispute shall be subject to the jurisdiction of courts having appropriate jurisdiction in India, subject to applicable law.',
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
                                'Depending on how you use CartAndOrder, we may collect name, email address, phone number, login/account information, business or shop information, shop/business address, business details, photographs/images, and certain device and usage information.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '1. Photographs and Images',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'CartAndOrder may allow you to upload photographs or images using your devices gallery/photo-selection functionality. Images may be used for profile, business/shop, product-related, or other Platform features. CartAndOrder does not access your entire photo library simply because you use the App; images are selected and uploaded through the relevant functionality and Android permissions.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '2. Device and Usage Information',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We and our service providers may collect technical and usage information such as device type, operating system information, app version, approximate usage information, diagnostics, app interactions/events, crash information, and performance information. The exact information may depend on device settings and the third-party services enabled in the App.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '3. How We Use Information',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We may use information to create and manage accounts, authenticate users, provide Platform features, display business and product information, generate estimates, verify business information, manage uploads, communicate with users, provide support, improve the App, analyze performance, prevent fraud or abuse, and comply with applicable legal obligations.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '4. Third-Party Services',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'CartAndOrder uses Google Firebase for application infrastructure and related functions; Google Analytics to understand application usage, events, and performance; and Cloudinary for image/media storage, processing, and delivery. These providers may process information according to their applicable privacy policies and contractual arrangements with us.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '5. Sharing of Information',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We do not sell your personal information as a standalone product. We may share information when reasonably necessary to operate the Platform, with service providers processing information on our behalf, with authorized users where required for Platform functionality, to comply with law or legal processes, to protect rights and security, or in connection with a business transfer, subject to applicable law.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '6. Business Information Visibility',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Because CartAndOrder is a B2B catalogue platform, certain business information may be displayed to other authorized users or relevant Platform participants where necessary for the service. Users should avoid uploading sensitive personal information that is not required for the intended functionality.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '7. Data Retention',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We retain information for as long as reasonably necessary to provide the Platform, maintain business/account records, meet legal, tax, accounting, security, or regulatory requirements, resolve disputes, prevent fraud and abuse, and enforce agreements. When information is no longer reasonably required, it may be deleted, anonymized, or otherwise disposed of in accordance with applicable law and operational requirements.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '8. Account and Data Deletion',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You may request deletion of your CartAndOrder account and associated personal information by contacting us at [Official Support Email]. We may need to verify account ownership. Certain information may be retained where required by law or for legitimate legal, fraud-prevention, dispute-resolution, or record-keeping purposes.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '9. Data Security',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We take reasonable technical and organizational measures designed to protect information against unauthorized access, alteration, disclosure, loss, or misuse. However, no internet-based application or electronic storage system can be guaranteed to be completely secure.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '10. Childrens Privacy',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'CartAndOrder is intended primarily for business and B2B users. The App is not intended to knowingly collect personal information from children for purposes unrelated to providing the service.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '11. International Processing',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Although CartAndOrder operates in India, third-party providers may process or store information using infrastructure located in India or other countries, depending on the services and infrastructure used. Where applicable, such processing will be subject to appropriate contractual, technical, and legal safeguards.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '12. Your Rights',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Subject to applicable law, you may have rights to request access to certain information, correction of inaccurate information, deletion where legally applicable, withdrawal of consent where processing is based on consent, and to raise a privacy-related complaint or grievance.',
                                style: TextStyle(height: 1.5),
                              ),
                              SizedBox(height: 14),
                              Text(
                                '13. Changes to This Privacy Policy',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'We may update this Privacy Policy when our services, technology, legal requirements, or data practices change. The updated version will be made available through the App or other appropriate channels. The “Last Updated” date indicates when it was most recently revised.',
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
              return 'Enter an email such as name@gmail.com';
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
