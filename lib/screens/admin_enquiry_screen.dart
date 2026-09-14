import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEnquiryDashboardScreen extends StatefulWidget {
  const AdminEnquiryDashboardScreen({super.key});

  @override
  State<AdminEnquiryDashboardScreen> createState() =>
      _AdminEnquiryDashboardScreenState();
}

class _AdminEnquiryDashboardScreenState
    extends State<AdminEnquiryDashboardScreen> {
  static const statuses = [
    'submitted',
    'in_review',
    'contacted',
    'resolved',
    'rejected',
  ];

  final _searchController = TextEditingController();

  // Keep one stream while changing search and status filters.
  final _enquiriesStream = FirebaseFirestore.instance
      .collection('enquiries')
      .snapshots();

  final comments = <String, TextEditingController>{};
  final busy = <String>{};

  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
  _buyerProfiles = {};

  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
  _activityStreams = {};

  final _scrollBehavior = const MaterialScrollBehavior().copyWith(
    scrollbars: false,
    overscroll: false,
  );

  String filter = 'All';
  String _search = '';

  TextEditingController controller(String id) =>
      comments.putIfAbsent(id, () => TextEditingController());

  String _text(dynamic value) => (value ?? '').toString().trim();

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _status(dynamic value) {
    final normalized = _normalize(
      _text(value),
    ).replaceAll(RegExp(r'[\s-]+'), '_');

    return normalized.isEmpty ? 'submitted' : normalized;
  }

  String label(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Color statusColor(String value) {
    switch (_status(value)) {
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'in_review':
        return Colors.blue;
      case 'contacted':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  String date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 16);
    }
    final text = _text(value);
    return text.isEmpty ? 'Pending' : text;
  }

  int _createdTime(Map<String, dynamic> data) {
    final value = data['createdAt'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copyValue(String value, String field) async {
    final text = value.trim();

    if (text.isEmpty || text.toLowerCase() == 'not provided') {
      message('No ${field.toLowerCase()} available.');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) message('$field copied.');
    } catch (_) {
      if (mounted) message('Could not copy ${field.toLowerCase()}.');
    }
  }

  void _searchChanged(String value) {
    setState(() {
      _search = _normalize(value);
      // Show every status when starting or changing a buyer search.
      filter = 'All';
    });
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;

    final buyerName = _normalize(_text(data['buyerName']));
    final buyerId = _normalize(_text(data['buyerId']));

    return buyerName.contains(_search) || buyerId.contains(_search);
  }

  Future<void> updateStatus(String id, String value) async {
    if (busy.contains(id) || !statuses.contains(value)) return;

    setState(() => busy.add(id));

    try {
      final ref = FirebaseFirestore.instance.collection('enquiries').doc(id);
      final activity = ref.collection('activity').doc();
      final batch = FirebaseFirestore.instance.batch();

      // Save the status and its history together.
      batch.update(ref, {
        'status': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(activity, {
        'type': 'status',
        'text': 'Status changed to ${label(value)}',
        'sender': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      if (mounted) message('Status updated to ${label(value)}.');
    } catch (_) {
      if (mounted) message('Could not update status. Please try again.');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> postComment(String id) async {
    final c = controller(id);
    final text = c.text.trim();

    if (text.isEmpty || busy.contains(id)) return;

    if (text.length > 5000) {
      message('Please keep your comment within 5,000 characters.');
      return;
    }

    setState(() => busy.add(id));

    try {
      await FirebaseFirestore.instance
          .collection('enquiries')
          .doc(id)
          .collection('activity')
          .add({
            'type': 'comment',
            'text': text,
            'sender': 'Admin',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      if (c.text.trim() == text) c.clear();
      message('Comment posted.');
    } catch (_) {
      if (mounted) message('Could not post comment.');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    for (final c in comments.values) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _scrollBehavior,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('Admin Enquiry Management'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                // Recreate the field when search resets the selected status.
                key: ValueKey<String>('status-filter-$filter'),
                value: filter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter status',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                items: ['All', ...statuses]
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status == 'All' ? 'All' : label(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => filter = value);
                  }
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _enquiriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Could not load enquiries. Check your connection '
                          'and approved Admin access.',
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
                    return const Center(child: Text('No enquiries yet.'));
                  }

                  final visible = allDocs.where((doc) {
                    final data = doc.data();
                    final matchesStatus =
                        filter == 'All' || _status(data['status']) == filter;

                    return matchesStatus && _matchesSearch(data);
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
                          'No enquiries match your search and status filter.',
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
                          '${visible.length} enquiries found',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<String>) return null;

                            final index = visible.indexWhere(
                              (doc) => doc.id == key.value,
                            );

                            return index < 0 ? null : index;
                          },
                          itemBuilder: (_, index) => buildCard(visible[index]),
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

  Widget buildCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final id = doc.id;
    final current = _status(data['status']);
    final image = _text(data['productImage']);

    final activityStream = _activityStreams.putIfAbsent(
      id,
      () =>
          doc.reference.collection('activity').orderBy('createdAt').snapshots(),
    );

    return Card(
      key: ValueKey<String>(id),
      margin: const EdgeInsets.only(bottom: 14),
      child: ExpansionTile(
        key: PageStorageKey<String>('enquiry-$id'),
        maintainState: true,
        title: Row(
          children: [
            Expanded(
              child: Text(
                _text(data['productName']).isEmpty
                    ? 'Enquiry'
                    : _text(data['productName']),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            _statusBadge(current),
          ],
        ),
        subtitle: Text(
          'Buyer: ${_text(data['buyerName']).isEmpty ? 'Unknown' : _text(data['buyerName'])}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image.isNotEmpty) ...[
                  Image.network(
                    image,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('Image unavailable'),
                  ),
                  const SizedBox(height: 10),
                ],
                _detail('Buyer name', data['buyerName']),
                _detail('Buyer ID', data['buyerId']),
                _copyDetail('Contact', data['mobileNumber'], 'Contact number'),
                _buyerAddress(data),
                _detail('Email', data['buyerEmail']),
                _copyDetail('Product ID', data['productId'], 'Product ID'),
                _detail('Submitted', date(data['createdAt'])),
                if (data['updatedAt'] != null)
                  _detail('Status updated', date(data['updatedAt'])),
                const SizedBox(height: 10),
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: activityStream,
                  builder: (_, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Could not load activity.'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(),
                      );
                    }

                    if (snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('No activity yet.'),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!.docs.map((activity) {
                        final d = activity.data();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${d['sender'] ?? 'Admin'} • '
                            '${date(d['createdAt'])}\n${d['text'] ?? ''}',
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey<String>('comment-$id'),
                        controller: controller(id),
                        readOnly: busy.contains(id),
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          hintText: 'Admin comment',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: busy.contains(id)
                          ? null
                          : () => postComment(id),
                      child: const Text('Post'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: statuses.map((status) {
                    return OutlinedButton(
                      onPressed: busy.contains(id) || status == current
                          ? null
                          : () => updateStatus(id, status),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: statusColor(status),
                      ),
                      child: Text(label(status)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor(value).withOpacity(.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label(value),
        style: TextStyle(
          color: statusColor(value),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buyerAddress(Map<String, dynamic> enquiry) {
    final uid = _text(enquiry['buyerId']);
    final saved = _text(enquiry['buyerAddress']);

    if (uid.isEmpty) {
      return _detail('Address', saved.isNotEmpty ? saved : 'Buyer ID missing');
    }

    final stream = _buyerProfiles.putIfAbsent(
      uid,
      () => FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    );

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _detail(
            'Address',
            saved.isNotEmpty ? saved : 'Unable to read Buyer profile',
          );
        }

        if (!snapshot.hasData) {
          return _detail(
            'Address',
            saved.isNotEmpty ? saved : 'Loading address…',
          );
        }

        final address = _text(snapshot.data!.data()?['shopAddress']);

        return _detail(
          'Address',
          address.isNotEmpty
              ? address
              : saved.isNotEmpty
              ? saved
              : 'No address saved in Buyer profile',
        );
      },
    );
  }

  Widget _copyDetail(String title, dynamic value, String copyLabel) {
    final text = _text(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(title, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(text.isEmpty ? 'Not provided' : text)),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Color(0xFF0052FF)),
            tooltip: 'Copy ${copyLabel.toLowerCase()}',
            onPressed: text.isEmpty ? null : () => _copyValue(text, copyLabel),
          ),
        ],
      ),
    );
  }

  Widget _detail(String title, dynamic value) {
    final text = _text(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(title, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(text.isEmpty ? 'Not provided' : text)),
        ],
      ),
    );
  }
}
