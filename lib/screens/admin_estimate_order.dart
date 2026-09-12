import 'package:flutter/material.dart';

class EstimatedOrdersScreen extends StatelessWidget {
  const EstimatedOrdersScreen({super.key});

  final List<Map<String, dynamic>> _estimatedOrders = const [
    {
      'estimateId': 'EST-2026-001',
      'date': '07 Sep 2026',
      'shopName': 'Dipak Store',
      'status': 'Pending Approval',
      'totalAmount': 14250,
      'items': [
        {'name': 'Universal Wall Socket', 'qty': 100, 'unitPrice': 350},
        {'name': 'LED Bulb 12W', 'qty': 50, 'unitPrice': 220},
      ],
    },
    {
      'estimateId': 'EST-2026-002',
      'date': '02 Sep 2026',
      'shopName': 'Electro World',
      'status': 'Approved',
      'totalAmount': 22500,
      'items': [
        {'name': 'Copper Wire 2.5mm Heavy Duty', 'qty': 10, 'unitPrice': 2250},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Estimated Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _estimatedOrders.isEmpty
          ? const Center(
              child: Text(
                'No estimated orders found.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _estimatedOrders.length,
              itemBuilder: (context, index) {
                final order = _estimatedOrders[index];
                return _buildOrderCard(context, order);
              },
            ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final List<dynamic> items = order['items'];

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
                order['estimateId'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black,
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
                      Icons.storefront,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order['shopName'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      order['date'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Estimated Total: ₹${order['totalAmount']}',
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
            const SizedBox(height: 10),
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

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['name']} (x${item['qty']})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '₹${item['unitPrice'] * item['qty']}',
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
          ],
        ),
      ),
    );
  }
}
