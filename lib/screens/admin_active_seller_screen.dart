import 'package:flutter/material.dart';

class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _sellers = [
    {
      'id': 'SEL-101',
      'imageUrl': 'https://i.pravatar.cc/150?img=11',
      'firstName': 'Rajesh',
      'lastName': 'Gupta',
      'shopName': 'Gupta Electricals & Lighting',
      'businessCategory': 'Electrical & Lighting',
      'gstinOrPan': '07ABCDE1234F1Z5 (GSTIN)',
      'shopAddress': 'Shop 12, Main Market, Chandni Chowk, Delhi - 110006',
      'email': 'rajesh.gupta@example.com',
      'mobile': '+91 98112 33445',
      'status': 'Approved',
    },
    {
      'id': 'SEL-102',
      'imageUrl': 'https://i.pravatar.cc/150?img=12',
      'firstName': 'Vikram',
      'lastName': 'Malhotra',
      'shopName': 'Apex Cable & Wires Mfg',
      'businessCategory': 'Manufacturing & Cables',
      'gstinOrPan': '24XYZAB5678G2Z9 (GSTIN)',
      'shopAddress':
          'Plot 45, GIDC Industrial Estate, Phase 2, Ahmedabad - 380015',
      'email': 'vikram.malhotra@apexcables.in',
      'mobile': '+91 98765 11223',
      'status': 'Pending',
    },
    {
      'id': 'SEL-103',
      'imageUrl': 'https://i.pravatar.cc/150?img=13',
      'firstName': 'Sunil',
      'lastName': 'Mehta',
      'shopName': 'Mehta Switchgears & Automation',
      'businessCategory': 'Electrical Switchgears',
      'gstinOrPan': '08MMMMP9999M1Z3 (GSTIN)',
      'shopAddress': '12 B, Industrial Area, Jaipur, Rajasthan - 302001',
      'email': 'sunil@mehtaswitch.com',
      'mobile': '+91 94140 88990',
      'status': 'Suspended',
    },
  ];

  List<String> get _categories {
    final categories = _sellers
        .map((s) => s['businessCategory'] as String)
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<Map<String, dynamic>> get _filteredSellers {
    if (_selectedCategory == 'All') {
      return _sellers;
    }
    return _sellers
        .where((s) => s['businessCategory'] == _selectedCategory)
        .toList();
  }

  void _updateStatus(Map<String, dynamic> seller, String newStatus) {
    setState(() {
      seller['status'] = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${seller['shopName']} status updated to $newStatus'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Suspended':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return const Color(0xFF0052FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredSellers;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Active Sellers Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Category Filter Horizontal List
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0052FF),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0052FF)
                            : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          // Sellers List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final seller = filteredList[index];
                final Color statusColor = _getStatusColor(seller['status']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.all(16),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: NetworkImage(seller['imageUrl']),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: statusColor,
                          ),
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${seller['firstName']} ${seller['lastName']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              seller['status'],
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              seller['shopName'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.blueGrey.shade100,
                                ),
                              ),
                              child: Text(
                                seller['businessCategory'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.person_outline,
                          label: 'Seller Name',
                          value: '${seller['firstName']} ${seller['lastName']}',
                        ),
                        _buildDetailRow(
                          icon: Icons.storefront_outlined,
                          label: 'Shop Name',
                          value: seller['shopName'],
                        ),
                        _buildDetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: seller['businessCategory'],
                        ),
                        _buildDetailRow(
                          icon: Icons.badge_outlined,
                          label: 'GSTIN / PAN',
                          value: seller['gstinOrPan'],
                        ),
                        _buildDetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Shop Address',
                          value: seller['shopAddress'],
                        ),
                        _buildDetailRow(
                          icon: Icons.email_outlined,
                          label: 'Email Address',
                          value: seller['email'],
                        ),
                        _buildDetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Mobile Number',
                          value: seller['mobile'],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: seller['status'] == 'Approved'
                                    ? null
                                    : () => _updateStatus(seller, 'Approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Approve',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: seller['status'] == 'Suspended'
                                    ? null
                                    : () => _updateStatus(seller, 'Suspended'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                  side: BorderSide(
                                    color: seller['status'] == 'Suspended'
                                        ? Colors.orange
                                        : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Suspend',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: seller['status'] == 'Rejected'
                                    ? null
                                    : () => _updateStatus(seller, 'Rejected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(
                                    color: seller['status'] == 'Rejected'
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
