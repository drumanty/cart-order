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
  final statuses = [
    'submitted',
    'in_review',
    'contacted',
    'resolved',
    'rejected',
  ];
  final comments = <String, TextEditingController>{};
  final busy = <String>{};
  String filter = 'All';

  TextEditingController controller(String id) =>
      comments.putIfAbsent(id, TextEditingController.new);
  String label(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}')
      .join(' ');
  Color statusColor(String value) => value == 'resolved'
      ? Colors.green
      : value == 'rejected'
      ? Colors.red
      : value == 'in_review'
      ? Colors.blue
      : Colors.orange;
  String date(dynamic value) => value is Timestamp
      ? value.toDate().toLocal().toString().substring(0, 16)
      : (value ?? 'Pending').toString();
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> copyPhone(String phone) async {
    final value = phone.trim();
    if (value.isEmpty || value == 'Not provided') {
      message('No contact number available.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted)
      message('Contact number copied. You can paste it into your phone.');
  }

  Future<void> updateStatus(String id, String value) async {
    if (busy.contains(id)) return;
    setState(() => busy.add(id));
    try {
      final ref = FirebaseFirestore.instance.collection('enquiries').doc(id);
      await ref.update({
        'status': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await ref.collection('activity').add({
        'type': 'status',
        'text': 'Status changed to ${label(value)}',
        'sender': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) message('Could not update status.');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> postComment(String id) async {
    final c = controller(id);
    final text = c.text.trim();
    if (text.isEmpty || busy.contains(id)) return;
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
      c.clear();
    } catch (_) {
      if (mounted) message('Could not post comment.');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  void dispose() {
    for (final c in comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('enquiries')
        .orderBy('createdAt', descending: true);
    if (filter != 'All') query = query.where('status', isEqualTo: filter);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Admin Enquiry Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: filter,
              decoration: const InputDecoration(
                labelText: 'Filter status',
                border: OutlineInputBorder(),
              ),
              items: ['All', ...statuses]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s == 'All' ? s : label(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => filter = v);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Text('Could not load enquiries. Check Admin rules.'),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty)
                  return const Center(child: Text('No enquiries yet.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (_, i) => buildCard(snapshot.data!.docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final id = doc.id;
    final current = (data['status'] ?? 'submitted').toString();
    final image = (data['productImage'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                (data['productName'] ?? 'Enquiry').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _statusBadge(current),
          ],
        ),
        subtitle: Text('Buyer: ${data['buyerName'] ?? 'Unknown'}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image.isNotEmpty)
                  Image.network(
                    image,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('Image unavailable'),
                  ),
                _detail('Buyer name', data['buyerName']),
                _contactDetail(data['mobileNumber']),
                _buyerAddress(data),
                _detail('Email', data['buyerEmail']),
                _detail('Product ID', data['productId']),
                _detail('Submitted', date(data['createdAt'])),
                const SizedBox(height: 10),
                const Text(
                  'Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: doc.reference
                      .collection('activity')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (_, snapshot) => Column(
                    children:
                        snapshot.data?.docs.map((a) {
                          final d = a.data();
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '${d['sender'] ?? 'Admin'} • ${date(d['createdAt'])}\n${d['text'] ?? ''}',
                              ),
                            ),
                          );
                        }).toList() ??
                        [],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller(id),
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
                Wrap(
                  spacing: 6,
                  children: statuses
                      .map(
                        (s) => OutlinedButton(
                          onPressed: busy.contains(id) || s == current
                              ? null
                              : () => updateStatus(id, s),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: statusColor(s),
                          ),
                          child: Text(label(s)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String value) => Container(
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
  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
  _buyerProfiles = {};

  Widget _buyerAddress(Map<String, dynamic> enquiry) {
    final uid = (enquiry['buyerId'] ?? '').toString().trim();
    final saved = (enquiry['buyerAddress'] ?? '').toString().trim();
    if (uid.isEmpty)
      return _detail('Address', saved.isNotEmpty ? saved : 'Buyer ID missing');
    final stream = _buyerProfiles.putIfAbsent(
      uid,
      () => FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    );
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _detail(
            'Address',
            saved.isNotEmpty ? saved : 'Unable to read Buyer profile',
          );
        if (!snapshot.hasData)
          return _detail(
            'Address',
            saved.isNotEmpty ? saved : 'Loading address…',
          );
        final address = (snapshot.data!.data()?['shopAddress'] ?? '')
            .toString()
            .trim();
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

  Widget _contactDetail(dynamic value) {
    final phone = (value ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 105,
            child: Text('Contact', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(phone.isEmpty ? 'Not provided' : phone)),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Color(0xFF0052FF)),
            tooltip: 'Copy contact number',
            onPressed: () => copyPhone(phone),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text((value ?? 'Not provided').toString())),
      ],
    ),
  );
}
