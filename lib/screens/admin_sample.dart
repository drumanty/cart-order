import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'product_details_screen.dart';

class AdminSampleScreen extends StatefulWidget {
  const AdminSampleScreen({super.key});

  @override
  State<AdminSampleScreen> createState() => _AdminSampleScreenState();
}

class _AdminSampleScreenState extends State<AdminSampleScreen> {
  static const List<String> _statuses = ['Pending', 'In Review', 'Approved'];

  final _requestsStream = FirebaseFirestore.instance
      .collection('sample_requests')
      .snapshots();

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();

  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _busy = {};

  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
  _activityStreams = {};

  static final ScrollBehavior _sampleScrollBehavior =
      const MaterialScrollBehavior().copyWith(
        scrollbars: false,
        overscroll: false,
      );

  String _filter = 'All';
  String _search = '';

  String _text(dynamic value) => (value ?? '').toString().trim();

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _status(dynamic value) {
    final normalized = _normalize(
      _text(value),
    ).replaceAll(RegExp(r'[_-]+'), ' ');

    switch (normalized) {
      case '':
      case 'pending':
        return 'Pending';
      case 'in review':
        return 'In Review';
      case 'approved':
        return 'Approved';
      default:
        return _text(value);
    }
  }

  String _buyerName(Map<String, dynamic> sample) {
    final name = _text(sample['userName']);
    return name.isNotEmpty ? name : _text(sample['buyerName']);
  }

  String _phone(Map<String, dynamic> sample) {
    final phone = _text(sample['userMobile']);
    return phone.isNotEmpty ? phone : _text(sample['mobileNumber']);
  }

  bool _hasCopyValue(String value) =>
      value.isNotEmpty && value.toLowerCase() != 'not provided';

  String _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 19);
    }

    final text = _text(value);
    return text.isEmpty ? 'Pending' : text;
  }

  int _createdTime(Map<String, dynamic> data) {
    final value = data['createdAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }

  TextEditingController _getController(String id) =>
      _commentControllers.putIfAbsent(id, () => TextEditingController());

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

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();

    for (final controller in _commentControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _resetScroll() {
    if (_listController.hasClients) {
      _listController.jumpTo(0);
    }
  }

  void _searchChanged(String value) {
    _resetScroll();

    setState(() {
      _search = _normalize(value);
      // Start each buyer search across every status.
      _filter = 'All';
    });
  }

  bool _matchesSearch(Map<String, dynamic> sample) {
    if (_search.isEmpty) return true;

    final name = _normalize(_buyerName(sample));
    final buyerId = _normalize(_text(sample['buyerId']));

    return name.contains(_search) || buyerId.contains(_search);
  }

  Future<void> _copyToClipboard(String text, String label) async {
    final value = text.trim();

    if (!_hasCopyValue(value)) {
      _message('No ${label.toLowerCase()} available.');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) _message('$label copied to clipboard.');
    } catch (_) {
      if (mounted) {
        _message('Could not copy ${label.toLowerCase()}.');
      }
    }
  }

  Future<void> _addComment(String id) async {
    final controller = _getController(id);
    final text = controller.text.trim();

    if (text.isEmpty || _busy.contains(id)) return;

    if (text.length > 5000) {
      _message('Please keep your comment within 5,000 characters.');
      return;
    }

    setState(() => _busy.add(id));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Please sign in again.');

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

      if (!mounted) return;

      if (controller.text.trim() == text) controller.clear();
      _message('Comment posted.');
    } catch (_) {
      if (mounted) _message('Could not save comment.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _updateAdminStatus(String id, String newStatus) async {
    if (_busy.contains(id) || !_statuses.contains(newStatus)) return;

    setState(() => _busy.add(id));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Please sign in again.');

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

      if (mounted) _message('Status updated to $newStatus.');
    } catch (_) {
      if (mounted) {
        _message('Could not save status and history.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
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
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (_status(status)) {
      case 'Approved':
        return Colors.green;
      case 'In Review':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _searchChanged,
                decoration: InputDecoration(
                  labelText: 'Search buyer name or Buyer ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _searchChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('sample-filter-$_filter'),
                initialValue: _filter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter by status',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: ['All', ..._statuses]
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  _resetScroll();
                  setState(() => _filter = value);
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _requestsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Could not load requests. Check your connection, '
                          'Admin access and sample request rules.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs;

                  if (allDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No sample requests found.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    );
                  }

                  final visible = allDocs.where((doc) {
                    final sample = doc.data();
                    final matchesStatus =
                        _filter == 'All' ||
                        _status(sample['status']) == _filter;

                    return matchesStatus && _matchesSearch(sample);
                  }).toList();

                  visible.sort((a, b) {
                    final comparison = _createdTime(
                      b.data(),
                    ).compareTo(_createdTime(a.data()));

                    return comparison == 0 ? a.id.compareTo(b.id) : comparison;
                  });

                  if (visible.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No sample requests match your search '
                          'and status filter.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${visible.length} sample requests found',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          key: const PageStorageKey<String>(
                            'sample-request-list',
                          ),
                          controller: _listController,
                          primary: false,
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<String>) return null;

                            final index = visible.indexWhere(
                              (doc) => 'sample-card-${doc.id}' == key.value,
                            );

                            return index < 0 ? null : index;
                          },
                          itemBuilder: (context, index) {
                            final doc = visible[index];
                            return _buildSampleCard(
                              context,
                              doc.id,
                              doc.data(),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleCard(
    BuildContext context,
    String id,
    Map<String, dynamic> sample,
  ) {
    final currentStatus = _status(sample['status']);
    final statusColor = _getStatusColor(currentStatus);
    final image = _text(sample['sampleImageUrl']);
    final buyerName = _buyerName(sample);
    final phone = _phone(sample);
    final buyerId = _text(sample['buyerId']);
    final productId = _text(sample['productID']);

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
            children: [
              Expanded(
                child: Text(
                  id,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
            padding: const EdgeInsets.only(top: 8),
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
                      buyerName.isEmpty ? 'Unknown buyer' : buyerName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _date(sample['createdAt']),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _hasCopyValue(phone)
                      ? () => _copyToClipboard(phone, 'Contact number')
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            phone.isEmpty ? 'Not provided' : phone,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: _hasCopyValue(phone)
                              ? const Color(0xFF0052FF)
                              : Colors.grey,
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
                    Expanded(
                      child: Text(
                        _text(sample['shopName']),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _text(sample['productName']),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0052FF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _text(sample['productID']),
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: productId.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailsScreen(productId: productId),
                          ),
                        );
                      },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0052FF),
                  side: const BorderSide(color: Color(0xFF0052FF)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _copyDetail('Buyer ID', buyerId),
            const SizedBox(height: 8),

            if (image.isNotEmpty) ...[
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
                  image,
                  '$id - ${_text(sample['productName'])}',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        image,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
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

            _detail('Email', sample['buyerEmail']),
            _detail('Buyer address', sample['buyerAddress']),
            _detail('Seller shop', sample['sellerShopName']),
            if (sample['updatedAt'] != null)
              _detail('Status updated', _date(sample['updatedAt'])),
            const SizedBox(height: 12),
            const Text(
              'Comments and status history',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activityStream(id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Unable to load activity.');
                }

                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No activity yet.'),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data();

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${data['sender'] ?? 'Admin'} • '
                        '${_date(data['createdAt'])}\n${data['text'] ?? ''}',
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
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
            Row(
              children: [
                Expanded(child: _statusButton(id, currentStatus, 'Pending')),
                const SizedBox(width: 6),
                Expanded(child: _statusButton(id, currentStatus, 'In Review')),
                const SizedBox(width: 6),
                Expanded(child: _statusButton(id, currentStatus, 'Approved')),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(String id, String current, String target) {
    final disabled = _busy.contains(id) || current == target;

    if (target == 'Approved') {
      return ElevatedButton(
        onPressed: disabled ? null : () => _updateAdminStatus(id, target),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(target, style: const TextStyle(fontSize: 11)),
      );
    }

    final color = _getStatusColor(target);

    return OutlinedButton(
      onPressed: disabled ? null : () => _updateAdminStatus(id, target),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: current == target ? color : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(target, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _copyDetail(String label, String value) {
    final available = _hasCopyValue(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              available ? value : 'Not provided',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Copy ${label.toLowerCase()}',
            icon: const Icon(Icons.copy, size: 18),
            color: const Color(0xFF0052FF),
            onPressed: available ? () => _copyToClipboard(value, label) : null,
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    final text = _text(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: ${text.isEmpty ? 'Not provided' : text}'),
      ),
    );
  }
}
