import 'package:flutter/material.dart';
import 'admin_estimate_order.dart';
import 'admin_enquiry_screen.dart';
import 'admin_sample.dart';
import 'admin_product_query_screen.dart';
import 'admin_active_buyer_screen.dart';
import 'admin_active_seller_screen.dart';
import 'admin_product_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Simple logout logic
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out of the admin panel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // TODO: Add your authentication logout logic / navigation to Login screen here
            },
            child: const Text('Logout'),
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            const Text(
              'Quick Navigation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildNavigationCard(
                  title: 'Active Buyer',
                  badge: '1,280',
                  icon: Icons.person_outline,
                  color: const Color(0xFF0052FF),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminBuyersScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Active Seller',
                  badge: '340',
                  icon: Icons.storefront_outlined,
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminSellersScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Product Catalog',
                  badge: '562',
                  icon: Icons.inventory_2_outlined,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminProductsScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Estimate Order',
                  badge: '14',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EstimatedOrdersScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Enquiry',
                  badge: '8',
                  icon: Icons.mark_chat_unread_outlined,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminEnquiryDashboardScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Sample Request',
                  badge: '5',
                  icon: Icons.local_post_office_outlined,
                  color: Colors.amber.shade800,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminSampleScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Product Query',
                  badge: '5',
                  icon: Icons.help_outline,
                  color: Colors.amber.shade800,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminProductQueryScreen(),
                      ),
                    );
                  },
                ),
                _buildNavigationCard(
                  title: 'Search Analytics',
                  badge: 'Live',
                  icon: Icons.analytics_outlined,
                  color: Colors.purple,
                  onTap: () {},
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
  }) {
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
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
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
