import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'estimate_service.dart';

// Shared card layout for Buyer and Admin, with role-specific controls.
class EstimateListView extends StatefulWidget {
  final bool adminView;
  const EstimateListView({super.key, this.adminView = false});
  @override
  State<EstimateListView> createState() => _EstimateListViewState();
}

class _EstimateListViewState extends State<EstimateListView> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String? _error;
  final Set<String> _busy = {};
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>> _history = {};
  static final _scrollBehavior = const MaterialScrollBehavior().copyWith(
    scrollbars: false,
    overscroll: false,
  );
  @override
  void initState() {
    super.initState();
    try {
      final collection = EstimateService.db.collection('estimated_orders');
      _stream = widget.adminView
          ? collection.snapshots()
          : collection
                .where('buyerId', isEqualTo: EstimateService.uid)
                .snapshots();
    } catch (e) {
      _error = EstimateService.error(e);
    }
  }

  Future<void> _status(String id, String value) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await EstimateService.status(id, value);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(EstimateService.error(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _copy(String mobile) async {
    await Clipboard.setData(ClipboardData(text: mobile));
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mobile number copied')));
  }

  Color _color(String status) => status == 'Approved'
      ? Colors.green
      : status == 'Rejected'
      ? Colors.red
      : status == 'In Review'
      ? Colors.blue
      : Colors.orange;
  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: _scrollBehavior,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Estimated Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Could not load estimates. Check your account access and Firestore rules.',
                      ),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final orders = snapshot.data!.docs.toList();
                orders.sort((a, b) {
                  final at = a.data()['createdAt'];
                  final bt = b.data()['createdAt'];
                  final av = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                  final bv = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                  return bv.compareTo(av);
                });
                if (orders.isEmpty)
                  return const Center(
                    child: Text(
                      'No estimated orders found.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                return ListView.builder(
                  key: const PageStorageKey<String>('estimated-order-list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final index = orders.indexWhere(
                      (doc) => doc.id == key.value,
                    );
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, index) => _card(orders[index]),
                );
              },
            ),
    ),
  );
  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final order = doc.data();
    final id = doc.id;
    final status = EstimateService.text(order['status']);
    final items = (order['items'] as List<dynamic>?) ?? [];
    final total = (order['totalPaise'] as num?)?.toInt() ?? 0;
    return Container(
      key: ValueKey<String>(id),
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
          key: PageStorageKey<String>('estimate-$id'),
          maintainState: true,
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            'EST-$id',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black,
            ),
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
                    Icon(
                      Icons.storefront,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    Text(
                      EstimateService.text(order['shopName']),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      EstimateService.date(order['createdAt']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimated Total: ${EstimateService.money(total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0052FF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$status • ${EstimateService.date(order['updatedAt'])}',
                  style: TextStyle(
                    color: _color(status),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1), const SizedBox(height: 10),
            if (widget.adminView) ...[
              _detail(
                'Buyer',
                '${order['buyerFirstName'] ?? ''} ${order['buyerLastName'] ?? ''}'
                    .trim(),
              ),
              _detail(
                'Buyer shop',
                EstimateService.text(order['buyerShopName']),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: EstimateService.text(order['buyerMobile']).isEmpty
                      ? null
                      : () => _copy(EstimateService.text(order['buyerMobile'])),
                  icon: const Icon(Icons.copy, size: 15),
                  label: Text('Mobile: ${order['buyerMobile'] ?? ''}'),
                ),
              ),
              _detail('Email', EstimateService.text(order['buyerEmail'])),
              _detail(
                'Buyer address',
                EstimateService.text(order['buyerAddress']),
              ),
              _detail('Seller ID', EstimateService.text(order['sellerId'])),
              const SizedBox(height: 10),
            ],
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Item Breakdown',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // A Column avoids adding nested scrolling widgets inside the expansion.
            for (final raw in items)
              Builder(
                builder: (context) {
                  final item = Map<String, dynamic>.from(raw as Map);
                  final qty = (item['qty'] as num).toInt();
                  final price = (item['unitPricePaise'] as num).toInt();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['name']} (x$qty)\n${EstimateService.money(price)} each • ${item['unitTypes'] ?? ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          EstimateService.money(price * qty),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            if (widget.adminView) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Update Estimate Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final value in [
                    'Pending Approval',
                    'In Review',
                    'Approved',
                    'Rejected',
                  ])
                    OutlinedButton(
                      onPressed: _busy.contains(id) || status == value
                          ? null
                          : () => _status(id, value),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _color(value),
                      ),
                      child: Text(value),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _history.putIfAbsent(
                id,
                () => doc.reference
                    .collection('activity')
                    .orderBy('createdAt')
                    .snapshots(),
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Text('Could not load status history.');
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final event in snapshot.data!.docs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${event.data()['status']} • ${EstimateService.date(event.data()['createdAt'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '$label: ${value.isEmpty ? 'Not provided' : value}',
        style: const TextStyle(fontSize: 13),
      ),
    ),
  );
}
