import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
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
      ),
      body: currentUser == null
          ? const Center(child: Text('No user logged in'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Profile data not found'));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;

                final String firstName = userData['firstName'] ?? '';
                final String lastName = userData['lastName'] ?? '';
                final String email = userData['email'] ?? '';
                final String mobile = userData['mobileNumber'] ?? '';
                final String userType = userData['userType'] ?? 'Buyer';
                final String shopName = userData['shopName'] ?? '';
                final String gstPan = userData['gstPanNumber'] ?? '';
                final String shopAddress = userData['shopAddress'] ?? '';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header / Profile Avatar
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: const Color(0xFFEBF2FF),
                              child: Text(
                                firstName.isNotEmpty
                                    ? firstName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0052FF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$firstName $lastName'.trim(),
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
                        value: mobile.isNotEmpty ? '+91 $mobile' : '',
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
                        icon: Icons.badge_outlined,
                        label: 'GSTIN / PAN Card',
                        value: gstPan,
                      ),
                      _buildDetailTile(
                        icon: Icons.location_on_outlined,
                        label: 'Shop Address',
                        value: shopAddress,
                      ),
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
                  value.isNotEmpty ? value : 'N/A',
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
