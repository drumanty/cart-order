import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class AdminProductQueryScreen extends StatefulWidget {
  const AdminProductQueryScreen({super.key});

  @override
  State<AdminProductQueryScreen> createState() =>
      _AdminProductQueryScreenState();
}

class _AdminProductQueryScreenState extends State<AdminProductQueryScreen> {
  Future<void> _copyValue(String label, String value) async {
    final text = value.trim();

    if (text.isEmpty || text.toLowerCase() == 'not provided') {
      _message('No ${label.toLowerCase()} available.');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _message('$label copied.');
    } catch (_) {
      if (mounted) _message('Could not copy ${label.toLowerCase()}.');
    }
  }

  Widget _copyDetail(String label, dynamic value) {
    final text = (value ?? '').toString().trim();
    final available = text.isNotEmpty && text.toLowerCase() != 'not provided';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              available ? text : 'Not provided',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Copy ${label.toLowerCase()}',
            icon: const Icon(Icons.copy, size: 18),
            color: const Color(0xFF0052FF),
            onPressed: available ? () => _copyValue(label, text) : null,
          ),
        ],
      ),
    );
  }

  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _busy = {};

  final TextEditingController _searchController = TextEditingController();

  final Stream<QuerySnapshot<Map<String, dynamic>>> _queriesStream =
      FirebaseFirestore.instance.collection('product_queries').snapshots();

  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
  _activityStreams = {};

  final _scrollBehavior = const MaterialScrollBehavior().copyWith(
    scrollbars: false,
    overscroll: false,
  );

  String _filter = 'All';
  String _search = '';

  static const List<String> _statuses = [
    'submitted',
    'in_review',
    'resolved',
    'rejected',
  ];

  @override
  void dispose() {
    _searchController.dispose();

    for (final c in _commentControllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  TextEditingController _controller(String id) =>
      _commentControllers.putIfAbsent(id, () => TextEditingController());

  String _text(dynamic value) => (value ?? '').toString().trim();

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _normalizeStatus(dynamic value) {
    final result = _normalize(_text(value)).replaceAll(RegExp(r'[\s-]+'), '_');

    return result.isEmpty ? 'submitted' : result;
  }

  String _label(String status) => status
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Color _statusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'resolved':
        return Colors.green;
      case 'in_review':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _money(dynamic value) {
    if (value is num) return '₹${value.toStringAsFixed(2)}';
    final text = _text(value);
    return text.isEmpty ? 'Not provided' : '₹$text';
  }

  String _date(dynamic value) {
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

  void _searchChanged(String value) {
    setState(() {
      _search = _normalize(value);
      _filter = 'All';
    });
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;

    final buyerName = _normalize(_text(data['buyerName']));
    final buyerId = _normalize(_text(data['buyerId']));

    return buyerName.contains(_search) || buyerId.contains(_search);
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _updateStatus(String id, String status) async {
    if (_busy.contains(id) || !_statuses.contains(status)) return;

    setState(() => _busy.add(id));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');

      final queryRef = FirebaseFirestore.instance
          .collection('product_queries')
          .doc(id);

      final activityRef = queryRef.collection('activity').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.update(queryRef, {
        'status': status,
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(activityRef, {
        'type': 'status',
        'status': status,
        'text': 'Status changed to ${_label(status)}',
        'senderId': uid,
        'sender': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        _message('Status updated to ${_label(status)}.');
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Could not update status. Check your connection and Admin access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _postComment(String id) async {
    final c = _controller(id);
    final text = c.text.trim();

    if (text.isEmpty || _busy.contains(id)) return;

    if (text.length > 5000) {
      _message('Please keep your comment within 5,000 characters.');
      return;
    }

    setState(() => _busy.add(id));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');

      final queryRef = FirebaseFirestore.instance
          .collection('product_queries')
          .doc(id);

      final activityRef = queryRef.collection('activity').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(activityRef, {
        'type': 'comment',
        'text': text,
        'senderId': uid,
        'sender': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(queryRef, {
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      if (c.text.trim() == text) c.clear();
      _message('Comment posted successfully.');
    } catch (_) {
      if (mounted) {
        _message(
          'Could not post comment. Check your connection and Admin access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _scrollBehavior,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('Buyer Product Queries'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: .5,
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('query-status-$_filter'),
                initialValue: _filter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter by status',
                  border: OutlineInputBorder(),
                ),
                items: ['All', ..._statuses]
                    .map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status == 'All' ? 'All' : _label(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _filter = value);
                  }
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _queriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Could not load queries. Check your connection '
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
                    return const Center(
                      child: Text('No product queries uploaded yet.'),
                    );
                  }

                  final visible = allDocs.where((doc) {
                    final data = doc.data();

                    final matchesStatus =
                        _filter == 'All' ||
                        _normalizeStatus(data['status']) == _filter;

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
                          'No product queries match your search '
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
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          '${visible.length} product queries found',
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
                          itemBuilder: (_, index) => _card(visible[index]),
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

  Widget _card(DocumentSnapshot<Map<String, dynamic>> doc) {
    final q = doc.data() ?? <String, dynamic>{};
    final id = doc.id;
    final status = _normalizeStatus(q['status']);
    final statusColor = _statusColor(status);
    final busy = _busy.contains(id);
    final image = _text(q['imageUrl']);
    final buyerName = _text(q['buyerName']);
    final buyerEmail = _text(q['buyerEmail']);

    final activityStream = _activityStreams.putIfAbsent(
      id,
      () =>
          doc.reference.collection('activity').orderBy('createdAt').snapshots(),
    );

    return Container(
      key: ValueKey<String>(id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('product-query-$id'),
          maintainState: true,
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Query ${id.substring(0, id.length > 8 ? 8 : id.length)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              _badge(_label(status), statusColor),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buyer: ${buyerName.isNotEmpty
                      ? buyerName
                      : buyerEmail.isNotEmpty
                      ? buyerEmail
                      : 'Unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  _text(q['productName']),
                  style: const TextStyle(
                    color: Color(0xFF0052FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_money(q['minPrice'])} – ${_money(q['maxPrice'])}'
                  '   •   Qty: ${q['quantity'] ?? 0} units',
                ),
              ],
            ),
          ),
          children: [
            const Divider(),
            _detail('Buyer name', q['buyerName']),
            _copyDetail('Contact number', q['mobileNumber']),
            _detail('Buyer email', q['buyerEmail']),
            _copyDetail('Buyer ID', q['buyerId']),
            _detail('Product name', q['productName']),
            _detail('Minimum price', _money(q['minPrice'])),
            _detail('Maximum price', _money(q['maxPrice'])),
            _detail('Required quantity', '${q['quantity'] ?? 0} units'),
            _detail('Description', q['description']),
            _detail('Submitted', _date(q['createdAt'])),
            _detail('Last updated', _date(q['updatedAt'])),
            if (image.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    image,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 50,
                      child: Center(child: Text('Image could not be loaded.')),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Activity and comments',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: activityStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Activity unavailable.');
                }

                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No comments or status history yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((activity) {
                    final d = activity.data();
                    final isComment = d['type'] == 'comment';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isComment
                            ? const Color(0xFFF0F5FF)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${d['sender'] ?? 'Admin'} • '
                        '${_date(d['createdAt'])}\n${d['text'] ?? ''}',
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
                    key: ValueKey<String>('query-comment-$id'),
                    controller: _controller(id),
                    readOnly: busy,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      hintText: 'Add an admin comment...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: busy ? null : () => _postComment(id),
                  child: const Text('Post'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Update status',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _statuses.map((value) {
                return OutlinedButton(
                  onPressed: busy || status == value
                      ? null
                      : () => _updateStatus(id, value),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _statusColor(value),
                  ),
                  child: Text(_label(value)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detail(String label, dynamic value) {
    final text = _text(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? 'Not provided' : text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
