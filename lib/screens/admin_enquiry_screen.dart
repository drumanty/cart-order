import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminEnquiryDashboardScreen extends StatefulWidget {
  const AdminEnquiryDashboardScreen({super.key});

  @override
  State<AdminEnquiryDashboardScreen> createState() =>
      _AdminEnquiryDashboardScreenState();
}

class _AdminEnquiryDashboardScreenState
    extends State<AdminEnquiryDashboardScreen> {
  final List<Map<String, dynamic>> _adminEnquiries = [
    {
      'enquiryId': 'ENQ-2026-001',
      'userName': 'Rahul Sharma',
      'userMobile': '+91 98765 43210',
      'productName': 'Smart Modular Touch Switch',
      'productID': 'PROD-2026-001',
      'productImage': 'https://via.placeholder.com/150',
      'shopName': 'Dipak Store',
      'date': '08 Sep 2026',
      'status': 'Pending',
      'comments': [
        {
          'sender': 'Admin',
          'text': 'Checking stock availability with the warehouse manager.',
          'time': '05 Sep 2026, 11:00 AM',
        },
      ],
    },
    {
      'enquiryId': 'ENQ-2026-002',
      'userName': 'Priya Patel',
      'userMobile': '+91 91234 56789',
      'productName': '3-Core 16mm Armoured Cable',
      'productID': 'PROD-2026-002',
      'productImage': 'https://via.placeholder.com/150',
      'shopName': 'Electro World',
      'date': '04 Sep 2026',
      'status': 'In Review',
      'comments': [
        {
          'sender': 'Admin',
          'text': 'Checking stock availability with the warehouse manager.',
          'time': '05 Sep 2026, 11:00 AM',
        },
      ],
    },
    {
      'enquiryId': 'ENQ-2026-003',
      'userName': 'Amit Verma',
      'userMobile': '+91 99887 76655',
      'productName': '12W LED Panel Light',
      'productID': 'PROD-2026-003',
      'productImage': 'https://via.placeholder.com/150',
      'shopName': 'Shree Electricals',
      'date': '01 Sep 2026',
      'status': 'Resolved',
      'comments': [
        {
          'sender': 'Admin',
          'text':
              'Offered a 10% discount on order above 50 units. User confirmed.',
          'time': '02 Sep 2026, 04:30 PM',
        },
      ],
    },
  ];

  final Map<int, TextEditingController> _commentControllers = {};

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(int index) {
    if (!_commentControllers.containsKey(index)) {
      _commentControllers[index] = TextEditingController();
    }
    return _commentControllers[index]!;
  }

  void _addComment(int index) {
    final controller = _getController(index);
    final text = controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      final List<Map<String, dynamic>> comments =
          _adminEnquiries[index]['comments'];
      comments.add({'sender': 'Admin', 'text': text, 'time': 'Just now'});
      controller.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment added successfully'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _updateAdminStatus(int index, String newStatus) {
    setState(() {
      _adminEnquiries[index]['status'] = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to "$newStatus"'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'In Review':
        return Colors.blue;
      case 'Pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Admin Enquiry Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _adminEnquiries.isEmpty
          ? const Center(
              child: Text(
                'No admin enquiries found.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _adminEnquiries.length,
              itemBuilder: (context, index) {
                final enquiry = _adminEnquiries[index];
                return _buildAdminCard(context, enquiry, index);
              },
            ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context,
    Map<String, dynamic> enquiry,
    int index,
  ) {
    final String currentStatus = enquiry['status'];
    final Color statusColor = _getStatusColor(currentStatus);
    final List<Map<String, dynamic>> comments = enquiry['comments'];
    final TextEditingController commentController = _getController(index);

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
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                enquiry['enquiryId'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentStatus,
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
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Name & Date
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      enquiry['userName'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      enquiry['date'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Mobile Number with Copy Button
                InkWell(
                  onTap: () =>
                      _copyToClipboard(enquiry['userMobile'], 'Mobile number'),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          enquiry['userMobile'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: Color(0xFF0052FF),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Shop Name
                Row(
                  children: [
                    Icon(
                      Icons.storefront,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      enquiry['shopName'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Product Details Row with Primary Image
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        enquiry['productImage'] ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey.shade500,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enquiry['productName'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0052FF),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            enquiry['productID'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Comments Header
            Row(
              children: [
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Comments (${comments.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Comments List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, cIndex) {
                final comment = comments[cIndex];
                final bool isAdmin = comment['sender'] == 'Admin';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? const Color(0xFFF0F5FF)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAdmin
                          ? const Color(0xFFD0E1FF)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            comment['sender'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isAdmin
                                  ? const Color(0xFF0052FF)
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            comment['time'],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment['text'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Add Comment Input Box
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add an internal or reply comment...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF0052FF)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addComment(index),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Post', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Admin Status Update Action',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Status Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentStatus == 'Pending'
                        ? null
                        : () => _updateAdminStatus(index, 'Pending'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(
                        color: currentStatus == 'Pending'
                            ? Colors.orange
                            : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentStatus == 'In Review'
                        ? null
                        : () => _updateAdminStatus(index, 'In Review'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade800,
                      side: BorderSide(
                        color: currentStatus == 'In Review'
                            ? Colors.blue
                            : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'In Review',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentStatus == 'Resolved'
                        ? null
                        : () => _updateAdminStatus(index, 'Resolved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Resolved',
                      style: TextStyle(fontSize: 11),
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
  }
}
