import 'package:flutter/material.dart';
import 'checkout_screen.dart';
import 'home_screen.dart';
import 'profile_details_screen.dart';
import 'estimated_order_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _selectedIndex = 1;

  final List<Map<String, dynamic>> _cartItems = [
    {
      'id': '1',
      'title': 'Universal Wall Socket',
      'color': 'White',
      'price': 4.25,
      'originalPrice': 5.00,
      'quantity': 1,
      'isSelected': true,
      'icon': Icons.power,
    },
    {
      'id': '2',
      'title': 'LED Bulb 12W',
      'color': 'White',
      'price': 2.80,
      'originalPrice': null,
      'quantity': 2,
      'isSelected': true,
      'icon': Icons.lightbulb_outline,
    },
    {
      'id': '3',
      'title': 'Copper Wire 2.5mm',
      'color': 'Red',
      'price': 28.50,
      'originalPrice': null,
      'quantity': 1,
      'isSelected': true,
      'icon': Icons.donut_large_outlined,
    },
  ];

  final double _freeDeliveryThreshold = 250.0;

  bool get _selectAll =>
      _cartItems.isNotEmpty && _cartItems.every((item) => item['isSelected']);

  double get _subtotal {
    double total = 0.0;
    for (var item in _cartItems) {
      if (item['isSelected']) {
        total += (item['price'] as double) * (item['quantity'] as int);
      }
    }
    return total;
  }

  int get _selectedCount {
    return _cartItems.where((item) => item['isSelected']).length;
  }

  double get _totalAmount => _subtotal;

  void _removeItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _removeAllSelected() {
    setState(() {
      _cartItems.removeWhere((item) => item['isSelected']);
    });
  }

  void _toggleSelectAll(bool? value) {
    if (value == null) return;
    setState(() {
      for (var item in _cartItems) {
        item['isSelected'] = value;
      }
    });
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const EstimatedOrdersScreen(),
          ),
        );
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
    double remainingForFreeDelivery = _freeDeliveryThreshold - _subtotal;
    if (remainingForFreeDelivery < 0) remainingForFreeDelivery = 0.0;
    double freeDeliveryProgress = (_subtotal / _freeDeliveryThreshold).clamp(
      0.0,
      1.0,
    );

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
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
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
                    // Free Delivery Progress Box
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.local_shipping,
                                color: Color(0xFF0052FF),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12.5,
                                    ),
                                    children: [
                                      const TextSpan(text: 'You are '),
                                      TextSpan(
                                        text:
                                            '₹${remainingForFreeDelivery.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF0052FF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' away from Minimum Order Amount!',
                                        style: TextStyle(
                                          color: Color(0xFF0052FF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: freeDeliveryProgress,
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF0052FF),
                                        ),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '₹${_freeDeliveryThreshold.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cart Items List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
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
                                child: Icon(
                                  item['icon'],
                                  size: 32,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _removeItem(index),
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
                                      item['color'],
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
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  if (item['quantity'] > 1) {
                                                    setState(() {
                                                      item['quantity']--;
                                                    });
                                                  }
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
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
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    item['quantity']++;
                                                  });
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        onPressed: _selectedCount == 0
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CheckoutScreen(),
                                  ),
                                );
                              },
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
