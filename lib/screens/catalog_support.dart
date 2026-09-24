import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

num catalogNumber(dynamic value) {
  if (value is num) return value.isFinite ? value : 0;
  return num.tryParse(
        value?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '') ?? '',
      ) ??
      0;
}

String catalogMoney(dynamic value) =>
    '₹ ${catalogNumber(value).toStringAsFixed(2)}';
String catalogError(Object error) {
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'Access denied. Check account approval and publish the product Firestore rules.';
    }
    if (error.code == 'unavailable') {
      return 'Connection unavailable. Please try again.';
    }
    return 'Could not complete the request (${error.code}). Please try again.';
  }
  return 'Could not complete the request. Please try again.';
}

Map<String, dynamic> catalogProduct(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final raw = doc.data() ?? <String, dynamic>{};
  final data = <String, dynamic>{...raw, 'id': doc.id};
  for (final key in [
    'productName',
    'category',
    'sellerId',
    'sellerName',
    'sellerShopName',
    'sellerShopAddress',
    'unitTypes',
    'description',
    'warranty',
    'frontImage',
    'backImage',
    'sideImage',
  ]) {
    data[key] = (raw[key] ?? '').toString();
  }
  for (final key in ['sellingPrice', 'mrp', 'unitPrice', 'mrpUnitPrice']) {
    data[key] = catalogMoney(raw[key]);
  }
  data['minOrderQuantity'] = (raw['minOrderQuantity'] ?? '').toString();
  data['howManyProductsInUnit'] = (raw['howManyProductsInUnit'] ?? '')
      .toString();
  data['ratings'] = catalogNumber(raw['ratings']);
  data['reviewCount'] = catalogNumber(raw['reviewCount']);
  data['status'] = (raw['status'] == 'Out of Stock')
      ? 'Approved'
      : (raw['status'] ?? 'Inactive').toString();
  data['isActive'] = raw['isActive'] ?? (data['status'] == 'Approved');
  data['inStock'] =
      raw['inStock'] ??
      (raw['stockStatus'] != 'Out of Stock' && raw['status'] != 'Out of Stock');
  data['stockStatus'] = data['inStock'] == true ? 'In Stock' : 'Out of Stock';
  return data;
}

Map<String, String> catalogCategory(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final raw = doc.data() ?? <String, dynamic>{};
  return {
    'id': doc.id,
    'name': (raw['name'] ?? '').toString().trim(),
    'imageUrl': (raw['imageUrl'] ?? '').toString().trim(),
    'imagePath': (raw['imagePath'] ?? '').toString().trim(),
  };
}

// Each mounted catalog observes Firestore and cancels its listeners on disposal.
mixin CatalogState<T extends StatefulWidget> on State<T> {
  bool get sellerProductsOnly => false;
  List<Map<String, dynamic>> catalogProducts = [];
  List<String> catalogCategories = [];
  List<Map<String, String>> catalogCategoryItems = [];
  bool catalogLoading = true;
  String? catalogFailure;
  String? categoryFailure;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _categorySubscription;
  @override
  void initState() {
    super.initState();
    restartCatalog();
  }

  void restartCatalog() {
    _productSubscription?.cancel();
    _categorySubscription?.cancel();
    catalogLoading = true;
    catalogFailure = null;
    categoryFailure = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      catalogProducts = [];
      catalogCategoryItems = [];
      catalogLoading = false;
      catalogFailure = 'Please sign in again.';
      return;
    }
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'products',
    );
    if (sellerProductsOnly) query = query.where('sellerId', isEqualTo: uid);
    _productSubscription = query.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final items = snapshot.docs.map(catalogProduct).toList();
        items.sort(
          (a, b) => a['productName'].toString().compareTo(
            b['productName'].toString(),
          ),
        );
        setState(() {
          catalogProducts = items;
          catalogLoading = false;
          catalogFailure = null;
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            catalogProducts = [];
            catalogLoading = false;
            catalogFailure = catalogError(error);
          });
        }
      },
    );
    _categorySubscription = FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            final categories =
                snapshot.docs
                    .map(catalogCategory)
                    .where((category) => category['name']!.isNotEmpty)
                    .toList()
                  ..sort((a, b) => a['name']!.compareTo(b['name']!));
            final names = categories
                .map((category) => category['name']!)
                .toSet()
                .toList();
            setState(() {
              catalogCategories = names;
              catalogCategoryItems = categories;
              categoryFailure = null;
            });
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                catalogCategories = [];
                catalogCategoryItems = [];
                categoryFailure = catalogError(error);
              });
            }
          },
        );
  }

  Widget catalogNotice() => Padding(
    padding: const EdgeInsets.all(16),
    child: catalogLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                catalogFailure ?? categoryFailure ?? 'No products found.',
                textAlign: TextAlign.center,
              ),
              if (catalogFailure != null || categoryFailure != null)
                TextButton(
                  onPressed: () => setState(restartCatalog),
                  child: const Text('Retry'),
                ),
            ],
          ),
  );
  @override
  void dispose() {
    _productSubscription?.cancel();
    _categorySubscription?.cancel();
    super.dispose();
  }
}

Widget catalogImage(String url, {double? width, double? height}) {
  Widget placeholder() => Container(
    width: width,
    height: height,
    color: const Color(0xFFF7F8FA),
    child: const Center(
      child: Icon(Icons.inventory_2_outlined, color: Color(0xFF0052FF)),
    ),
  );
  if (url.isEmpty) return placeholder();
  return Image.network(
    url,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => placeholder(),
  );
}

Widget catalogCategoryImage(
  String imageUrl, {
  double? width,
  double? height,
  IconData fallbackIcon = Icons.category_outlined,
}) {
  Widget placeholder() => Container(
    width: width,
    height: height,
    color: const Color(0xFFEBF2FF),
    child: Center(child: Icon(fallbackIcon, color: const Color(0xFF0052FF))),
  );

  if (imageUrl.isEmpty) return placeholder();
  return Image.network(
    imageUrl,
    width: width,
    height: height,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => placeholder(),
  );
}

void catalogComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature is not connected yet.')));
}
