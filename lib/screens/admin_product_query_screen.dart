import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminProductQueryScreen extends StatefulWidget {
  const AdminProductQueryScreen({super.key});
  @override
  State<AdminProductQueryScreen> createState() =>
      _AdminProductQueryScreenState();
}

class _AdminProductQueryScreenState extends State<AdminProductQueryScreen> {
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _busy = {};
  String _filter = 'All';
  final List<String> _statuses = [
    'submitted',
    'in_review',
    'resolved',
    'rejected',
  ];

  @override
  void dispose() {
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String id) =>
      _commentControllers.putIfAbsent(id, TextEditingController.new);
  String _label(String status) => status
      .replaceAll('_', ' ')
      .split(' ')
      .map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}')
      .join(' ');
  Color _statusColor(String status) => switch (status) {
    'resolved' => Colors.green,
    'in_review' => Colors.blue,
    'rejected' => Colors.red,
    _ => Colors.orange,
  };
  String _money(dynamic value) {
    if (value is num) return '₹${value.toStringAsFixed(2)}';
    return '₹${value ?? ''}';
  }

  Future<void> _updateStatus(String id, String status) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');
      await FirebaseFirestore.instance
          .collection('product_queries')
          .doc(id)
          .update({
            'status': status,
            'updatedBy': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      await FirebaseFirestore.instance
          .collection('product_queries')
          .doc(id)
          .collection('activity')
          .add({
            'type': 'status',
            'status': status,
            'text': 'Status changed to ${_label(status)}',
            'senderId': uid,
            'sender': 'Admin',
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      if (mounted) _message('Could not update status. Check Admin rules.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _postComment(String id) async {
    final c = _controller(id);
    final text = c.text.trim();
    if (text.isEmpty || text.length > 5000 || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');
      final queryRef = FirebaseFirestore.instance
          .collection('product_queries')
          .doc(id);
      await queryRef.collection('activity').add({
        'type': 'comment',
        'text': text,
        'senderId': uid,
        'sender': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await queryRef.update({
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      c.clear();
      if (mounted) _message('Comment posted successfully.');
    } catch (e) {
      if (mounted) _message('Could not post comment. Check Admin rules.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('product_queries')
        .orderBy('createdAt', descending: true);
    if (_filter != 'All') query = query.where('status', isEqualTo: _filter);
    return Scaffold(
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: DropdownButtonFormField<String>(
              initialValue: _filter,
              decoration: const InputDecoration(
                labelText: 'Filter by status',
                border: OutlineInputBorder(),
              ),
              items: ['All', ..._statuses]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s == 'All' ? s : _label(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _filter = v);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load queries. Check Admin rules.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No product queries uploaded yet.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) =>
                      _card(snapshot.data!.docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(DocumentSnapshot<Map<String, dynamic>> doc) {
    final q = doc.data() ?? {};
    final id = doc.id;
    final status = (q['status'] ?? 'submitted').toString();
    final statusColor = _statusColor(status);
    final busy = _busy.contains(id);
    final image = (q['imageUrl'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
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
              _badge(_label(status), statusColor),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buyer: ${(q['buyerName'] ?? q['buyerEmail'] ?? 'Unknown').toString()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  (q['productName'] ?? '').toString(),
                  style: const TextStyle(
                    color: Color(0xFF0052FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_money(q['minPrice'])} – ${_money(q['maxPrice'])}   •   Qty: ${q['quantity'] ?? 0} units',
                ),
              ],
            ),
          ),
          children: <Widget>[
            const Divider(),
            _detail('Buyer name', q['buyerName']),
            _detail('Contact number', q['mobileNumber']),
            _detail('Buyer email', q['buyerEmail']),
            _detail('Buyer ID', q['buyerId']),
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
              stream: doc.reference
                  .collection('activity')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Activity unavailable.');
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text(
                    'No comments or status history yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: snapshot.data!.docs.map((a) {
                    final d = a.data();
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
                        '${d['sender'] ?? 'Admin'} • ${_date(d['createdAt'])}\n${d['text'] ?? ''}',
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
                    controller: _controller(id),
                    enabled: !busy,
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
              children: _statuses
                  .map(
                    (s) => OutlinedButton(
                      onPressed: busy || status == s
                          ? null
                          : () => _updateStatus(id, s),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _statusColor(s),
                      ),
                      child: Text(_label(s)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
  Widget _detail(String label, dynamic value) => Padding(
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
            (value ?? 'Not provided').toString(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
  String _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().substring(0, 16);
    }
    return value?.toString() ?? 'Pending';
  }
}
