import 'package:flutter/material.dart';

import 'estimate_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await EstimateService.loadCart(EstimateService.uid);
      EstimateService.validate(items);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = EstimateService.error(error);
      });
    }
  }

  Future<void> _submitEstimate() async {
    if (_submitting || _items.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final buyerId = EstimateService.uid;
      final latestItems = await EstimateService.loadCart(buyerId);
      EstimateService.validate(latestItems);

      for (final sellerItems in EstimateService.group(latestItems).values) {
        await EstimateService.submitSeller(
          buyerId: buyerId,
          estimateId: EstimateService.db
              .collection('estimated_orders')
              .doc()
              .id,
          preview: sellerItems,
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Estimate submitted'),
          content: const Text(
            'Your estimate has been submitted for Admin review.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(EstimateService.error(error))));
      await _load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int get _totalPaise => EstimateService.total(_items);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _submitting ? null : () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Order Summary',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...EstimateService.group(
                          _items,
                        ).values.map(_sellerSummary),
                        const SizedBox(height: 12),
                        _totalCard(),
                      ],
                    ),
                  ),
                  _submitBar(),
                ],
              ),
            ),
    );
  }

  Widget _sellerSummary(List<Map<String, dynamic>> sellerItems) {
    final shopName = sellerItems.first['shopName'] as String;
    final subtotal = EstimateService.total(sellerItems);
    final minimum = sellerItems.first['minimumPaise'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${sellerItems.length} item${sellerItems.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Divider(height: 24),
          ...sellerItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${item['quantity']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    EstimateService.money(
                      (item['pricePaise'] as int) * (item['quantity'] as int),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          _summaryRow('Seller subtotal', EstimateService.money(subtotal)),
          if (minimum > 0) ...[
            const SizedBox(height: 6),
            _summaryRow('Minimum purchase', EstimateService.money(minimum)),
          ],
        ],
      ),
    );
  }

  Widget _totalCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF4FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: _summaryRow(
      'Total estimate amount',
      EstimateService.money(_totalPaise),
    ),
  );

  Widget _summaryRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0052FF),
        ),
      ),
    ],
  );

  Widget _submitBar() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, -3),
        ),
      ],
    ),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submitEstimate,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.receipt_long_rounded, color: Colors.white),
        label: Text(_submitting ? 'Submitting…' : 'GET ESTIMATE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0052FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
    ),
  );
}
