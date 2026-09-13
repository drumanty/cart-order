import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminSampleScreen extends StatefulWidget {
  const AdminSampleScreen({super.key});

  @override
  State<AdminSampleScreen> createState() => _AdminSampleScreenState();
}

class _AdminSampleScreenState extends State<AdminSampleScreen> {
  List<Map<String, dynamic>> _sampleRequests = [];
  final _requestsStream = FirebaseFirestore.instance
      .collection('sample_requests')
      .orderBy('createdAt', descending: true)
      .snapshots();
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _busy = {};
  // Keep scroll wrappers consistent when expansion and Firestore rebuild.
  static final ScrollBehavior _sampleScrollBehavior =
      const MaterialScrollBehavior().copyWith(
        scrollbars: false,
        overscroll: false,
      );
  final ScrollController _listController = ScrollController();
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
  _activityStreams = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _activityStream(String id) =>
      _activityStreams.putIfAbsent(
        id,
        () => FirebaseFirestore.instance
            .collection('sample_requests')
            .doc(id)
            .collection('activity')
            .orderBy('createdAt')
            .snapshots(),
      );
  String _date(dynamic v) => v is Timestamp
      ? v.toDate().toLocal().toString().substring(0, 19)
      : 'Saving…';
  @override
  void dispose() {
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    _listController.dispose();
    super.dispose();
  }

  TextEditingController _getController(String id) =>
      _commentControllers.putIfAbsent(id, () => TextEditingController());

  Future<void> _addComment(String id) async {
    final c = _getController(id);
    final text = c.text.trim();
    if (text.isEmpty || text.length > 5000 || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('sample_requests')
          .doc(id)
          .collection('activity')
          .add({
            'type': 'comment',
            'sender': 'Admin',
            'senderId': uid,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted && c.text.trim() == text) c.clear();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save comment.')),
        );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _updateAdminStatus(String id, String newStatus) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseFirestore.instance
          .collection('sample_requests')
          .doc(id);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(ref, {
        'status': newStatus,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(ref.collection('activity').doc(), {
        'type': 'status',
        'sender': 'Admin',
        'senderId': uid,
        'text': 'Status changed to $newStatus',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save status and history.')),
        );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
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
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _requestsStream,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Scaffold(
          appBar: AppBar(title: const Text('Sample Requests')),
          body: const Center(
            child: Text(
              'Could not load requests. Check Admin access and sample request rules.',
            ),
          ),
        );
      if (!snapshot.hasData)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      _sampleRequests = snapshot.data!.docs
          .map(
            (doc) => <String, dynamic>{
              ...doc.data(),
              'sampleId': doc.id,
              'date': _date(doc.data()['createdAt']),
            },
          )
          .toList();
      return _buildScreen(context);
    },
  );

  Widget _buildScreen(BuildContext context) {
    return ScrollConfiguration(
      behavior: _sampleScrollBehavior,
      child: Scaffold(
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
                key: const PageStorageKey<String>('sample-request-list'),
                controller: _listController,
                primary: false,
                findChildIndexCallback: (key) {
                  if (key is! ValueKey<String>) return null;
                  final index = _sampleRequests.indexWhere(
                    (sample) =>
                        'sample-card-${sample['sampleId']}' == key.value,
                  );
                  return index < 0 ? null : index;
                },
                padding: const EdgeInsets.all(16.0),
                itemCount: _sampleRequests.length,
                itemBuilder: (context, index) {
                  final sample = _sampleRequests[index];
                  return _buildSampleCard(context, sample, index);
                },
              ),
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
    final String id = sample['sampleId'];
    final String? sampleImageUrl = sample['sampleImageUrl'];

    return Container(
      key: ValueKey<String>('sample-card-$id'),
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
          key: PageStorageKey<String>('sample-expansion-$id'),
          maintainState: true,
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sample['sampleId'],
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black,
                  ),
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
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    Text(
                      sample['userName'],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sample['date'],
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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

            Text('Email: ${sample['buyerEmail'] ?? ''}'),
            Text('Buyer address: ${sample['buyerAddress'] ?? ''}'),
            Text('Seller shop: ${sample['sellerShopName'] ?? ''}'),
            const SizedBox(height: 12),
            const Text(
              'Comments and status history',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activityStream(id),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Text('Unable to load activity.');
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.docs.isEmpty)
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No activity yet.'),
                  );
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final d = doc.data();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${d['sender'] ?? 'Admin'} • ${_date(d['createdAt'])}\n${d['text'] ?? ''}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            // Add Comment Input Box
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey<String>('sample-comment-$id'),
                    controller: _getController(id),
                    readOnly: _busy.contains(id),
                    maxLength: 5000,
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
                  onPressed: _busy.contains(id) ? null : () => _addComment(id),
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
                    onPressed: _busy.contains(id) || currentStatus == 'Pending'
                        ? null
                        : () => _updateAdminStatus(id, 'Pending'),
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
                    onPressed:
                        _busy.contains(id) || currentStatus == 'In Review'
                        ? null
                        : () => _updateAdminStatus(id, 'In Review'),
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
                    onPressed: _busy.contains(id) || currentStatus == 'Approved'
                        ? null
                        : () => _updateAdminStatus(id, 'Approved'),
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
