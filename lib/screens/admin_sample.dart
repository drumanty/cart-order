import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminSampleScreen extends StatefulWidget {
  const AdminSampleScreen({super.key});

  @override
  State<AdminSampleScreen> createState() => _AdminSampleScreenState();
}

class _AdminSampleScreenState extends State<AdminSampleScreen> {
  final List<Map<String, dynamic>> _sampleRequests = [
    {
      'sampleId': 'SMP-2026-001',
      'userName': 'Rahul Sharma',
      'userMobile': '+91 98765 43210',
      'productID': 'PRD-2026-010',
      'productName': 'Smart Modular Touch Switch',
      'shopName': 'Dipak Store',
      'date': '08 Sep 2026',
      'status': 'Pending',
      'sampleImageUrl': 'https://picsum.photos/id/1/600/400',
      'comments': [
        {
          'sender': 'Admin',
          'text':
              'Sample request received. Will process and update the status shortly.',
          'time': '08 Sep 2026, 11:00 AM',
        },
      ],
    },
    {
      'sampleId': 'SMP-2026-002',
      'userName': 'Priya Patel',
      'userMobile': '+91 91234 56789',
      'productID': 'PRD-2026-011',
      'productName': '3-Core 16mm Armoured Cable',
      'shopName': 'Electro World',
      'date': '04 Sep 2026',
      'status': 'In Review',
      'sampleImageUrl': 'https://picsum.photos/id/10/600/400',
      'comments': [
        {
          'sender': 'Admin',
          'text':
              'Dispatched query to warehouse to arrange sample spool cutting.',
          'time': '05 Sep 2026, 11:00 AM',
        },
      ],
    },
    {
      'sampleId': 'SMP-2026-003',
      'userName': 'Amit Verma',
      'userMobile': '+91 99887 76655',
      'productID': 'PRD-2026-012',
      'productName': '12W LED Panel Light',
      'shopName': 'Shree Electricals',
      'date': '01 Sep 2026',
      'status': 'Approved',
      'sampleImageUrl': 'https://picsum.photos/id/20/600/400',
      'comments': [
        {
          'sender': 'Admin',
          'text':
              'Sample request approved. Courier tracking details updated in system.',
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
          _sampleRequests[index]['comments'];
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
      _sampleRequests[index]['status'] = newStatus;
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

  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
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
        title: const Text('Sample Requests'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _sampleRequests.isEmpty
          ? const Center(
              child: Text(
                'No sample requests found.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _sampleRequests.length,
              itemBuilder: (context, index) {
                final sample = _sampleRequests[index];
                return _buildSampleCard(context, sample, index);
              },
            ),
    );
  }

  Widget _buildSampleCard(
    BuildContext context,
    Map<String, dynamic> sample,
    int index,
  ) {
    final String currentStatus = sample['status'];
    final Color statusColor = _getStatusColor(currentStatus);
    final List<Map<String, dynamic>> comments = sample['comments'];
    final String? sampleImageUrl = sample['sampleImageUrl'];

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
                sample['sampleId'],
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
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sample['userName'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      sample['date'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () =>
                      _copyToClipboard(sample['userMobile'], 'Mobile number'),
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
                          sample['userMobile'],
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
                Row(
                  children: [
                    Icon(
                      Icons.storefront,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sample['shopName'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  sample['productName'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0052FF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sample['productID'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0052FF),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Sample Image Preview Section
            if (sampleImageUrl != null && sampleImageUrl.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sample Photo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showImagePreview(
                  context,
                  sampleImageUrl,
                  '${sample['sampleId']} - ${sample['productName']}',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        sampleImageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tap to expand',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                    controller: _getController(index),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add internal note or user update...',
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
                'Update Sample Status',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3 Status Action Buttons
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
                    onPressed: currentStatus == 'Approved'
                        ? null
                        : () => _updateAdminStatus(index, 'Approved'),
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
                      'Approved',
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
