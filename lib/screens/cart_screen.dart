import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'estimate_service.dart';
import 'package:flutter/material.dart';
import 'checkout_screen.dart';
import 'home_screen.dart';
import 'profile_details_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _selectedIndex = 1;

  List<Map<String, dynamic>> _cartItems = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _loadVersion = 0;
  double get _subtotal => EstimateService.total(_cartItems) / 100;
  int get _selectedCount => _cartItems.length;
  double get _totalAmount => _subtotal;

  @override
  void initState() {
    super.initState();
    try {
      _subscription = EstimateService.cart(EstimateService.uid)
          .snapshots()
          .listen(
            (_) => _refresh(),
            onError: (Object e) {
              if (mounted)
                setState(() {
                  _error = EstimateService.error(e);
                  _loading = false;
                });
            },
          );
    } catch (e) {
      _error = EstimateService.error(e);
      _loading = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final version = ++_loadVersion;
    try {
      final items = await EstimateService.loadCart(EstimateService.uid);
      if (mounted && version == _loadVersion)
        setState(() {
          _cartItems = items;
          _loading = false;
          _error = null;
        });
    } catch (e) {
      if (mounted && version == _loadVersion)
        setState(() {
          _error = EstimateService.error(e);
          _loading = false;
        });
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(EstimateService.error(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeItem(int index) {
    final id = _cartItems[index]['id'] as String;
    _mutate(() => EstimateService.cart(EstimateService.uid).doc(id).delete());
  }

  void _quantity(Map<String, dynamic> item, int delta) => _mutate(
    () => EstimateService.changeQuantity(item['id'] as String, delta),
  );
  Future<void> _checkout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final items = await EstimateService.loadCart(EstimateService.uid);
      EstimateService.validate(items);
      if (!mounted) return;
      setState(() => _cartItems = items);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
      );
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(EstimateService.error(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _minimumBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final items in EstimateService.group(_cartItems).values) ...[
            Text(
              items.first['shopName'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              EstimateService.total(items) >=
                      (items.first['minimumPaise'] as int)
                  ? 'Minimum purchase amount reached'
                  : 'Add ${EstimateService.money((items.first['minimumPaise'] as int) - EstimateService.total(items))} to reach this shop’s minimum',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (items.first['minimumPaise'] as int) == 0
                  ? 1.0
                  : (EstimateService.total(items) /
                            (items.first['minimumPaise'] as int))
                        .clamp(0.0, 1.0)
                        .toDouble(),
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0052FF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Minimum: ${EstimateService.money(items.first['minimumPaise'] as int)}',
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileDetailsScreen()),
        );
        break;
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Your Cart (${_cartItems.length})',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _cartItems.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty. Add products from Product Details.',
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        children: [
                          _minimumBox(),
                          const SizedBox(height: 16),

                          // Cart Items List
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              final item = _cartItems[index];
                              return Container(
                                key: ValueKey<String>(item['id'] as String),
                                margin: const EdgeInsets.only(bottom: 12.0),
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 65,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F8FA),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child:
                                          (item['imageUrl'] as String).isEmpty
                                          ? const Icon(
                                              Icons.inventory_2_outlined,
                                              size: 32,
                                            )
                                          : Image.network(
                                              item['imageUrl'] as String,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.broken_image_outlined,
                                                  ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item['title'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _busy
                                                    ? null
                                                    : () => _removeItem(index),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item['color']} • MOQ: ${item['minimumQuantity']}${item['available'] == true ? '' : ' • Unavailable'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '₹${(item['price'] as double).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0052FF),
                                                ),
                                              ),
                                              Container(
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: _busy
                                                          ? null
                                                          : () => _quantity(
                                                              item,
                                                              -1,
                                                            ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                            ),
                                                        child: Icon(
                                                          Icons.remove,
                                                          size: 14,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${item['quantity']}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: _busy
                                                          ? null
                                                          : () => _quantity(
                                                              item,
                                                              1,
                                                            ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                            ),
                                                        child: Icon(
                                                          Icons.add,
                                                          size: 14,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Summary Details Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _buildSummaryRow(
                                  'Subtotal ($_selectedCount items)',
                                  '₹${_subtotal.toStringAsFixed(2)}',
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₹${_totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0052FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Secure Checkout Badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF8EE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: Color(0xFF2E7D32),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Checkout Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0052FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _busy || _selectedCount == 0
                                  ? null
                                  : _checkout,
                              child: Text(
                                'Checkout ($_selectedCount)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF0052FF),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
