import 'package:flutter/material.dart';

class AdminProductQueryScreen extends StatefulWidget {
  const AdminProductQueryScreen({super.key});

  @override
  State<AdminProductQueryScreen> createState() =>
      _AdminProductQueryScreenState();
}

class _AdminProductQueryScreenState extends State<AdminProductQueryScreen> {
  final List<Map<String, dynamic>> _productQueries = [
    {
      'queryId': 'PQ-2026-001',
      'userName': 'Rahul Sharma',
      'productName': 'Modular Switch Panel',
      'minPrice': '150',
      'maxPrice': '300',
      'quantity': 50,
      'description':
          'Looking for high-durability modular switch panels with silver trim. Needs to meet standard commercial electrical specifications.',
      'imageUrl':
          'https://via.placeholder.com/150', // Replace with real network image URL
      'date': '08 Sep 2026',
      'status': 'Pending',
      'comments': [
        {
          'sender': 'Admin',
          'text': 'Verified with manufacturer. Certificates are available.',
          'time': '06 Sep 2026, 11:00 AM',
        },
      ],
    },
    {
      'queryId': 'PQ-2026-002',
      'userName': 'Priya Patel',
      'productName': '3-Core 16mm Armoured Cable',
      'minPrice': '1200',
      'maxPrice': '1500',
      'quantity': 10,
      'description':
          'Need heavy-duty underground cable for outdoor industrial setup. Must be ISI certified.',
      'imageUrl': null, // Case where no photo was uploaded
      'date': '05 Sep 2026',
      'status': 'In Review',
      'comments': [
        {
          'sender': 'Admin',
          'text': 'Verified with manufacturer. Certificates are available.',
          'time': '06 Sep 2026, 11:00 AM',
        },
      ],
    },
    {
      'queryId': 'PQ-2026-003',
      'userName': 'Amit Verma',
      'productName': '12W LED Concealed Panel Light',
      'minPrice': '200',
      'maxPrice': '350',
      'quantity': 120,
      'description':
          'Bulk requirement for residential project. Cool white 6500K color temperature preferred.',
      'imageUrl': 'https://via.placeholder.com/150',
      'date': '02 Sep 2026',
      'status': 'Resolved',
      'comments': [
        {
          'sender': 'Admin',
          'text': 'Quotation sent to buyer email. Deal confirmed.',
          'time': '03 Sep 2026, 04:30 PM',
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
          _productQueries[index]['comments'];
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

  void _updateStatus(int index, String newStatus) {
    setState(() {
      _productQueries[index]['status'] = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to "$newStatus"'),
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
        title: const Text('Buyer Product Queries'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _productQueries.isEmpty
          ? const Center(
              child: Text(
                'No product queries uploaded yet.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _productQueries.length,
              itemBuilder: (context, index) {
                final query = _productQueries[index];
                return _buildQueryCard(context, query, index);
              },
            ),
    );
  }

  Widget _buildQueryCard(
    BuildContext context,
    Map<String, dynamic> query,
    int index,
  ) {
    final String currentStatus = query['status'];
    final Color statusColor = _getStatusColor(currentStatus);
    final List<Map<String, dynamic>> comments = query['comments'];
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
                query['queryId'],
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
                // Buyer Name & Date
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      query['userName'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      query['date'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Product Title
                Text(
                  query['productName'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0052FF),
                  ),
                ),
                const SizedBox(height: 6),

                // Price Range & Quantity Badges
                Row(
                  children: [
                    _buildInfoBadge(
                      icon: Icons.currency_rupee,
                      label: '₹${query['minPrice']} - ₹${query['maxPrice']}',
                      color: Colors.green.shade700,
                      bgColor: Colors.green.shade50,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoBadge(
                      icon: Icons.inventory_2_outlined,
                      label: 'Qty: ${query['quantity']} units',
                      color: Colors.purple.shade700,
                      bgColor: Colors.purple.shade50,
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Product Image (If uploaded by buyer)
            if (query['imageUrl'] != null) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Uploaded Product Reference',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  query['imageUrl'],
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Buyer Description Header
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Description & Specifications',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                query['description'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                      hintText: 'Add an admin response or note...',
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
                'Update Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Status Update Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: currentStatus == 'Pending'
                        ? null
                        : () => _updateStatus(index, 'Pending'),
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
                        : () => _updateStatus(index, 'In Review'),
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
                        : () => _updateStatus(index, 'Resolved'),
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

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
