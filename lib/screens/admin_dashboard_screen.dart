import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_active_buyer_screen.dart';
import 'admin_active_seller_screen.dart';
import 'admin_enquiry_screen.dart';
import 'admin_estimate_order.dart';
import 'admin_product_query_screen.dart';
import 'admin_product_screen.dart';
import 'admin_sample.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _buyersStream =>
      _db.collection('users').where('userType', isEqualTo: 'Buyer').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _sellersStream => _db
      .collection('users')
      .where('userType', isEqualTo: 'Seller')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _productsStream =>
      _db.collection('products').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestsWithStatus(
    String collection,
    String status,
  ) {
    return _db
        .collection(collection)
        .where('status', isEqualTo: status)
        .snapshots();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out of the admin panel?',
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  String _countText(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  Widget _buildUserCard({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildNavigationCard(
            title: title,
            badge: 'Unable to load',
            icon: icon,
            color: color,
            onTap: onTap,
          );
        }

        if (!snapshot.hasData) {
          return _buildNavigationCard(
            title: title,
            badge: 'Loading...',
            icon: icon,
            color: color,
            onTap: onTap,
          );
        }

        final users = snapshot.data!.docs
            .map((document) => document.data())
            .toList();
        final activeCount = users
            .where((user) => user['accountStatus'] == 'approved')
            .length;
        final pendingCount = users
            .where((user) => user['accountStatus'] == 'pending')
            .length;

        return _buildNavigationCard(
          title: title,
          badge: _countText(activeCount, 'active', 'active'),
          secondaryBadge: _countText(
            pendingCount,
            'new request',
            'new requests',
          ),
          secondaryBadgeColor: pendingCount > 0
              ? Colors.redAccent
              : Colors.grey,
          notificationCount: pendingCount,
          icon: icon,
          color: color,
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildProductCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildNavigationCard(
            title: 'Product Catalog',
            badge: 'Unable to load',
            icon: Icons.inventory_2_outlined,
            color: Colors.teal,
            onTap: _openProducts,
          );
        }

        if (!snapshot.hasData) {
          return _buildNavigationCard(
            title: 'Product Catalog',
            badge: 'Loading...',
            icon: Icons.inventory_2_outlined,
            color: Colors.teal,
            onTap: _openProducts,
          );
        }

        final availableCount = snapshot.data!.docs.where((document) {
          final product = document.data();
          return product['status'] == 'Approved' && product['isActive'] == true;
        }).length;

        return _buildNavigationCard(
          title: 'Product Catalog',
          badge: _countText(availableCount, 'product', 'products'),
          icon: Icons.inventory_2_outlined,
          color: Colors.teal,
          onTap: _openProducts,
        );
      },
    );
  }

  Widget _buildRequestCard({
    required String title,
    required String collection,
    required String waitingStatus,
    required String emptyLabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestsWithStatus(collection, waitingStatus),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildNavigationCard(
            title: title,
            badge: 'Unable to load',
            icon: icon,
            color: color,
            onTap: onTap,
          );
        }

        if (!snapshot.hasData) {
          return _buildNavigationCard(
            title: title,
            badge: 'Loading...',
            icon: icon,
            color: color,
            onTap: onTap,
          );
        }

        final waitingCount = snapshot.data!.docs.length;
        return _buildNavigationCard(
          title: title,
          badge: waitingCount == 0
              ? emptyLabel
              : _countText(waitingCount, 'new request', 'new requests'),
          notificationCount: waitingCount,
          icon: icon,
          color: color,
          onTap: onTap,
        );
      },
    );
  }

  void _openBuyers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminBuyersScreen()),
    );
  }

  void _openSellers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminSellersScreen()),
    );
  }

  void _openProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminProductsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Control Center',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Quick Navigation & Activity',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF0052FF),
            child: Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const Text(
              'Quick Navigation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Red badges show only items waiting for your action.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.80,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildUserCard(
                  title: 'Active Buyer',
                  icon: Icons.person_outline,
                  color: const Color(0xFF0052FF),
                  stream: _buyersStream,
                  onTap: _openBuyers,
                ),
                _buildUserCard(
                  title: 'Active Seller',
                  icon: Icons.storefront_outlined,
                  color: Colors.indigo,
                  stream: _sellersStream,
                  onTap: _openSellers,
                ),
                _buildProductCard(),
                _buildRequestCard(
                  title: 'Estimate Order',
                  collection: 'estimated_orders',
                  waitingStatus: 'Pending Approval',
                  emptyLabel: 'No pending orders',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EstimatedOrdersScreen(),
                      ),
                    );
                  },
                ),
                _buildRequestCard(
                  title: 'Enquiry',
                  collection: 'enquiries',
                  waitingStatus: 'submitted',
                  emptyLabel: 'No new enquiries',
                  icon: Icons.mark_chat_unread_outlined,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminEnquiryDashboardScreen(),
                      ),
                    );
                  },
                ),
                _buildRequestCard(
                  title: 'Sample Request',
                  collection: 'sample_requests',
                  waitingStatus: 'Pending',
                  emptyLabel: 'No new samples',
                  icon: Icons.local_post_office_outlined,
                  color: Colors.amber.shade800,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminSampleScreen()),
                    );
                  },
                ),
                _buildRequestCard(
                  title: 'Product Query',
                  collection: 'product_queries',
                  waitingStatus: 'submitted',
                  emptyLabel: 'No new queries',
                  icon: Icons.help_outline,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminProductQueryScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Search Analytics',
                  badge: 'Coming soon',
                  icon: Icons.analytics_outlined,
                  color: Colors.blueGrey,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Search analytics will be added next.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String badge,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? notificationCount,
    String? secondaryBadge,
    Color? secondaryBadgeColor,
  }) {
    final hasNotification = notificationCount != null && notificationCount > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (hasNotification)
                  Positioned(
                    right: -9,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        notificationCount > 99
                            ? '99+'
                            : notificationCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (secondaryBadge != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (secondaryBadgeColor ?? Colors.redAccent).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  secondaryBadge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryBadgeColor ?? Colors.redAccent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
