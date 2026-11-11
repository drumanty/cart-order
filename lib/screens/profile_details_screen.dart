import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  bool _loggingOut = false;
  bool _requestingDeletion = false;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log out (${error.code}).')),
      );

      setState(() => _loggingOut = false);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );

      setState(() => _loggingOut = false);
    }
  }

  Future<void> _handleDeleteAccount(String userType) async {
    if (_requestingDeletion || _loggingOut) return;

    if (userType != 'Buyer' && userType != 'Seller') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Buyer and Seller accounts can request deletion.'),
        ),
      );
      return;
    }

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Request Account Deletion')),
          ],
        ),
        content: const Text(
          'Your request will be sent to the Admin for review. '
          'Your account will remain active while the request is pending. '
          'If approved, access will be deactivated while the deletion process '
          'is completed. Data that must legally be retained may be kept as '
          'described in the Privacy Policy.',
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
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (shouldSubmit != true || !mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again to continue.')),
      );
      return;
    }

    setState(() => _requestingDeletion = true);

    try {
      final requestRef = FirebaseFirestore.instance
          .collection('account_deletion_requests')
          .doc(currentUser.uid);
      final existing = await requestRef.get();
      final status = (existing.data()?['status'] ?? '').toString();

      if (existing.exists && status == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your deletion request is already pending.'),
            ),
          );
        }
      } else if (existing.exists && status == 'approved_for_deletion') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your request has already been approved.'),
            ),
          );
        }
      } else {
        await requestRef.set({
          'uid': currentUser.uid,
          'email': currentUser.email ?? '',
          'userType': userType,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account deletion request was submitted.'),
            ),
          );
        }
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit request (${error.code}).')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit your request. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
    }
  }

  Widget _buildDeletionSection({
    required String uid,
    required String userType,
  }) {
    final requestStream = FirebaseFirestore.instance
        .collection('account_deletion_requests')
        .doc(uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: requestStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = (data?['status'] ?? '').toString();

        Widget? statusCard;
        if (snapshot.hasError) {
          statusCard = _deletionStatusCard(
            icon: Icons.error_outline,
            color: Colors.orange,
            title: 'Request status unavailable',
            message: 'Please check your connection and try again.',
          );
        } else if (status == 'pending') {
          statusCard = _deletionStatusCard(
            icon: Icons.hourglass_top,
            color: Colors.orange,
            title: 'Deletion request pending',
            message:
                'Your account is still active. The Admin has not reviewed your request yet.',
          );
        } else if (status == 'rejected') {
          statusCard = _deletionStatusCard(
            icon: Icons.info_outline,
            color: Colors.redAccent,
            title: 'Deletion request rejected',
            message:
                'Your account remains active. You may submit a new request if you still want to delete your account.',
          );
        } else if (status == 'approved_for_deletion') {
          statusCard = _deletionStatusCard(
            icon: Icons.lock_outline,
            color: Colors.deepOrange,
            title: 'Deletion approved',
            message:
                'Your account access has been deactivated. The Admin is completing the deletion process. This does not mean your data has already been deleted.',
          );
        }

        final canSubmit =
            status != 'pending' &&
            status != 'approved_for_deletion' &&
            !snapshot.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (statusCard != null) ...[statusCard, const SizedBox(height: 12)],
            if (canSubmit)
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
                      : const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                  label: Text(
                    _requestingDeletion
                        ? 'Submitting Request...'
                        : 'Delete Account',
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
      },
    );
  }

  Widget _deletionStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
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

                final canRequestDeletion =
                    userType == 'Buyer' || userType == 'Seller';

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
                      // Account deletion is available only to Buyers and Sellers.
                      if (canRequestDeletion) ...[
                        _buildDeletionSection(
                          uid: currentUser.uid,
                          userType: userType,
                        ),
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
