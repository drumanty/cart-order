import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'catalog_support.dart';

class ShopMinimumEditor extends StatefulWidget {
  const ShopMinimumEditor({super.key});
  @override
  State<ShopMinimumEditor> createState() => _ShopMinimumEditorState();
}

class _ShopMinimumEditorState extends State<ShopMinimumEditor> {
  final _amount = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');
      final doc = await FirebaseFirestore.instance
          .collection('shop_settings')
          .doc(uid)
          .get();
      if (!mounted) return;
      final value = doc.data()?['minimumPurchaseAmount'];
      _amount.text = value is num ? value.toStringAsFixed(2) : '';
    } catch (e) {
      if (mounted) _error = catalogError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || !value.isFinite || value < 0 || value > 1000000000) {
      setState(() => _error = 'Enter a valid amount from 0 to 1,000,000,000.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Signed out');
      await FirebaseFirestore.instance
          .collection('shop_settings')
          .doc(uid)
          .set({
            'minimumPurchaseAmount': (value * 100).round() / 100,
            'updatedBy': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop minimum purchase amount saved.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = catalogError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shop Minimum Purchase Amount',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator()
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum Purchase Amount (₹)',
                    hintText: 'e.g. 1000',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        const SizedBox(height: 6),
        const Text(
          'Applies to your whole shop. Enter 0 for no minimum.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_error != null && !_saving)
          TextButton(
            onPressed: _load,
            child: const Text('Reload saved amount'),
          ),
      ],
    ),
  );
}

class ShopMinimumBadge extends StatefulWidget {
  final String sellerId;
  const ShopMinimumBadge({super.key, required this.sellerId});
  @override
  State<ShopMinimumBadge> createState() => _ShopMinimumBadgeState();
}

class _ShopMinimumBadgeState extends State<ShopMinimumBadge> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  void _bind() {
    _stream = widget.sellerId.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('shop_settings')
              .doc(widget.sellerId)
              .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant ShopMinimumBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sellerId != widget.sellerId) _bind();
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          String text = 'Minimum Purchase\nNot set by seller';
          if (snapshot.hasError) {
            text = 'Minimum Purchase\nUnavailable';
          } else if (_stream != null &&
              snapshot.connectionState == ConnectionState.waiting)
            text = 'Minimum Purchase\nLoading…';
          else {
            final amount = snapshot.data?.data()?['minimumPurchaseAmount'];
            if (amount is num) {
              text = amount == 0
                  ? 'Minimum Purchase\nNo minimum'
                  : 'Minimum Purchase\n${catalogMoney(amount)}';
            }
          }
          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF2FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0052FF), width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 14,
                  color: Color(0xFF0052FF),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0052FF),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
