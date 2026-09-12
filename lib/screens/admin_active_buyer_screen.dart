import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_navigation.dart';

class AdminBuyersScreen extends StatefulWidget {
  const AdminBuyersScreen({super.key});

  @override
  State<AdminBuyersScreen> createState() => _AdminBuyersScreenState();
}

class _AdminBuyersScreenState extends State<AdminBuyersScreen> {
  String _selectedCategory = 'All';

  List<Map<String, dynamic>> _buyers = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _loading = true;
  String? _loadError;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'Buyer')
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _buyers = snapshot.docs.map((doc) {
                final data = doc.data();
                String field(String name) => data[name]?.toString() ?? '';
                final rawStatus = field('accountStatus');
                final status = switch (rawStatus) {
                  'approved' => 'Approved',
                  'suspended' => 'Suspended',
                  'rejected' => 'Rejected',
                  _ => 'Pending',
                };
                return <String, dynamic>{
                  'id': doc.id,
                  'imageUrl': field('photoUrl'),
                  'firstName': field('firstName'),
                  'lastName': field('lastName'),
                  'shopName': field('shopName'),
                  'businessCategory': field('businessCategory'),
                  'gstinOrPan': field('gstPanNumber'),
                  'shopAddress': field('shopAddress'),
                  'email': field('email'),
                  'mobile': field('mobileNumber'),
                  'status': status,
                };
              }).toList();
              if (!_categories.contains(_selectedCategory))
                _selectedCategory = 'All';
              _loading = false;
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _buyers = [];
              _loading = false;
              _loadError =
                  'Unable to load accounts. Check your admin role, rules and connection.';
            });
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<String> get _categories {
    final categories = _buyers
        .map((b) => b['businessCategory'] as String)
        .toSet()
        .toList();
    return ['All', ...categories];
  }

  // Filter buyers based on selected category
  List<Map<String, dynamic>> get _filteredBuyers {
    if (_selectedCategory == 'All') {
      return _buyers;
    }
    return _buyers
        .where((b) => b['businessCategory'] == _selectedCategory)
        .toList();
  }

  Future<void> _updateStatus(
    Map<String, dynamic> buyer,
    String newStatus,
  ) async {
    final uid = buyer['id'] as String;
    if (_saving.contains(uid)) return;
    setState(() => _saving.add(uid));
    try {
      final admin = FirebaseAuth.instance.currentUser;
      if (admin == null) throw const FormatException('Please log in again.');
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'accountStatus': newStatus.toLowerCase(),
        'reviewedBy': admin.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Account set to $newStatus')));
      }
    } catch (error) {
      if (mounted) showAuthError(context, error);
    } finally {
      if (mounted) setState(() => _saving.remove(uid));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Suspended':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return const Color(0xFF0052FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredBuyers;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Active Buyers Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!),
              ),
            )
          : _buyers.isEmpty
          ? const Center(child: Text('No buyers have registered yet.'))
          : Column(
              children: [
                // Horizontal Slider Category Filter
                Container(
                  height: 56,
                  color: Colors.white,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;

                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0052FF),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0052FF)
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE0E0E0)),

                // Buyers List
                Expanded(
                  child: filteredList.isEmpty
                      ? const Center(
                          child: Text(
                            'No buyers found in this category',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final buyer = filteredList[index];
                            final Color statusColor = _getStatusColor(
                              buyer['status'],
                            );

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
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.all(16),
                                  childrenPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage:
                                        (buyer['imageUrl'] as String).isNotEmpty
                                        ? NetworkImage(
                                            buyer['imageUrl'] as String,
                                          )
                                        : null,
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: CircleAvatar(
                                        radius: 8,
                                        backgroundColor: statusColor,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${buyer['firstName']} ${buyer['lastName']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          buyer['status'],
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      buyer['shopName'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    _buildDetailRow(
                                      icon: Icons.person_outline,
                                      label: 'Buyer Name',
                                      value:
                                          '${buyer['firstName']} ${buyer['lastName']}',
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.category_outlined,
                                      label: 'Category',
                                      value: buyer['businessCategory'],
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.storefront_outlined,
                                      label: 'Shop / Firm Name',
                                      value: buyer['shopName'],
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.badge_outlined,
                                      label: 'GSTIN / PAN',
                                      value: buyer['gstinOrPan'],
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.location_on_outlined,
                                      label: 'Shop Address',
                                      value: buyer['shopAddress'],
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.email_outlined,
                                      label: 'Email Address',
                                      value: buyer['email'],
                                    ),
                                    _buildDetailRow(
                                      icon: Icons.phone_outlined,
                                      label: 'Mobile Number',
                                      value: buyer['mobile'],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed:
                                                _saving.contains(buyer['id']) ||
                                                    buyer['status'] ==
                                                        'Approved'
                                                ? null
                                                : () => _updateStatus(
                                                    buyer,
                                                    'Approved',
                                                  ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Approve',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed:
                                                _saving.contains(buyer['id']) ||
                                                    buyer['status'] ==
                                                        'Suspended'
                                                ? null
                                                : () => _updateStatus(
                                                    buyer,
                                                    'Suspended',
                                                  ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  Colors.orange.shade800,
                                              side: BorderSide(
                                                color:
                                                    buyer['status'] ==
                                                        'Suspended'
                                                    ? Colors.orange
                                                    : Colors.grey.shade300,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Suspend',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed:
                                                _saving.contains(buyer['id']) ||
                                                    buyer['status'] ==
                                                        'Rejected'
                                                ? null
                                                : () => _updateStatus(
                                                    buyer,
                                                    'Rejected',
                                                  ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: BorderSide(
                                                color:
                                                    buyer['status'] ==
                                                        'Rejected'
                                                    ? Colors.red
                                                    : Colors.grey.shade300,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Reject',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
