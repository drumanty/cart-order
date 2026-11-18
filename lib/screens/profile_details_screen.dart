import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  bool _loggingOut = false;
  bool _requestingDeletion = false;

  static const String _deleteAccountFunctionUrl =
      'https://delete-my-account-y4mhbmpjja-uc.a.run.app';

  Future<void> _handleLogout() async {
    if (_loggingOut || _requestingDeletion) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    setState(() => _loggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showMessage('Could not log out (${error.code}).');
      setState(() => _loggingOut = false);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Could not log out. Please try again.');
      setState(() => _loggingOut = false);
    }
  }

  Future<Map<String, String>?> _showReauthenticationDialog(
    String currentEmail,
  ) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReauthenticationDialog(currentEmail: currentEmail),
    );
  }

  Future<void> _handleDeleteAccount(String userType) async {
    if (_requestingDeletion || _loggingOut) return;

    final normalizedRole = userType.trim().toLowerCase();

    if (normalizedRole != 'buyer' && normalizedRole != 'seller') {
      _showMessage('Only Buyer and Seller accounts can delete their accounts.');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('Please log in again to continue.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Delete Account Permanently')),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\n'
          'Your login account and personal profile will be deleted. '
          'Some business records may be retained or anonymized '
          'where required for business or legal purposes.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final credentials = await _showReauthenticationDialog(
      currentUser.email ?? '',
    );

    if (credentials == null || !mounted) return;

    setState(() => _requestingDeletion = true);

    try {
      final email = credentials['email']?.trim() ?? '';
      final password = credentials['password'] ?? '';

      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Please enter your email and password.',
        );
      }

      final accountEmail = currentUser.email ?? '';

      if (accountEmail.toLowerCase() != email.toLowerCase()) {
        throw FirebaseAuthException(
          code: 'email-mismatch',
          message: 'The entered email does not match your account.',
        );
      }

      // Reauthenticate the current Firebase user.
      final authCredential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await currentUser.reauthenticateWithCredential(authCredential);

      // Get a fresh Firebase ID token.
      final idToken = await currentUser.getIdToken(true);

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Could not obtain authentication token.');
      }

      // Call the deployed account-deletion function.
      final response = await http
          .post(
            Uri.parse(_deleteAccountFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'action': 'deleteMyAccount'}),
          )
          .timeout(const Duration(seconds: 60));

      Map<String, dynamic> responseData = {};

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          responseData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        responseData = {};
      }
      debugPrint('DELETE ACCOUNT HTTP STATUS: ${response.statusCode}');
      debugPrint('DELETE ACCOUNT RESPONSE BODY: ${response.body}');
      debugPrint('DELETE ACCOUNT PARSED DATA: $responseData');

      if (response.statusCode != 200 || responseData['success'] != true) {
        final message =
            responseData['message']?.toString() ??
            responseData['error']?.toString() ??
            'Account deletion failed. Check the debug response.';

        throw Exception('HTTP ${response.statusCode}: $message');
      }

      // The backend reports successful deletion.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      String message;

      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
          break;

        case 'user-mismatch':
        case 'email-mismatch':
          message = 'The entered email does not match your account.';
          break;

        case 'requires-recent-login':
          message = 'Please sign in again and retry.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'invalid-input':
          message = error.message ?? 'Please enter your credentials.';
          break;

        default:
          message = error.message ?? 'Authentication failed. Please try again.';
      }

      _showMessage(message);
    } catch (error) {
      if (!mounted) return;

      String message = error.toString();

      message = message.replaceFirst('Exception: ', '');

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _requestingDeletion = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Widget _buildDeletionSection({required String userType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account Deletion',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'You can permanently delete your account '
                'without waiting for Admin approval. '
                'Some business records may be retained '
                'where required.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: (_loggingOut || _requestingDeletion)
                ? null
                : () => _handleDeleteAccount(userType),
            icon: _requestingDeletion
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.redAccent,
                    ),
                  )
                : const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: Text(
              _requestingDeletion ? 'Deleting Account...' : 'Delete Account',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: (_loggingOut || _requestingDeletion)
              ? null
              : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: (_loggingOut || _requestingDeletion)
                ? null
                : _handleLogout,
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('No user logged in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load your profile. Please try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.data!.exists) {
                  return const Center(child: Text('Profile data not found'));
                }

                final userData = snapshot.data!.data() ?? <String, dynamic>{};

                final firstName = (userData['firstName'] ?? '').toString();
                final lastName = (userData['lastName'] ?? '').toString();
                final email = (userData['email'] ?? '').toString();
                final mobile = (userData['mobileNumber'] ?? '').toString();
                final userType = (userData['userType'] ?? 'User').toString();
                final shopName = (userData['shopName'] ?? '').toString();
                final shopAddress = (userData['shopAddress'] ?? '').toString();

                final fullName = '$firstName $lastName'.trim();

                final initial = firstName.isNotEmpty
                    ? firstName.substring(0, 1).toUpperCase()
                    : 'U';

                final normalizedRole = userType.trim().toLowerCase();

                final canDeleteAccount =
                    normalizedRole == 'buyer' || normalizedRole == 'seller';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: const Color(0xFFEBF2FF),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              fullName.isEmpty ? 'User' : fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF2FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                userType,
                                style: const TextStyle(
                                  color: Color(0xFF0052FF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailTile(
                        icon: Icons.person_outline,
                        label: 'First Name',
                        value: firstName,
                      ),
                      _buildDetailTile(
                        icon: Icons.person_outline,
                        label: 'Last Name',
                        value: lastName,
                      ),
                      _buildDetailTile(
                        icon: Icons.email_outlined,
                        label: 'Email Address',
                        value: email,
                      ),
                      _buildDetailTile(
                        icon: Icons.phone_outlined,
                        label: 'Mobile Number',
                        value: mobile.isEmpty ? '' : '+91 $mobile',
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Business / Shop Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailTile(
                        icon: Icons.storefront_outlined,
                        label: 'Shop Name',
                        value: shopName,
                      ),
                      _buildDetailTile(
                        icon: Icons.location_on_outlined,
                        label: 'Shop Address',
                        value: shopAddress,
                      ),
                      const SizedBox(height: 16),
                      if (canDeleteAccount) ...[
                        _buildDeletionSection(userType: userType),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: (_loggingOut || _requestingDeletion)
                              ? null
                              : _handleLogout,
                          icon: _loggingOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : const Icon(
                                  Icons.logout,
                                  color: Colors.redAccent,
                                ),
                          label: Text(
                            _loggingOut ? 'Logging out...' : 'Logout',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Separate dialog widget.
//
// The controllers belong to this widget and are disposed when the
// dialog is removed from the widget tree.
class _ReauthenticationDialog extends StatefulWidget {
  final String currentEmail;

  const _ReauthenticationDialog({required this.currentEmail});

  @override
  State<_ReauthenticationDialog> createState() =>
      _ReauthenticationDialogState();
}

class _ReauthenticationDialogState extends State<_ReauthenticationDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(text: widget.currentEmail);

    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
      });
      return;
    }

    Navigator.of(context).pop({'email': email, 'password': password});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Your Identity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For security, please enter your email and password '
              'before deleting your account.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
