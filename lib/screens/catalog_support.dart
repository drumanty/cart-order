import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

num catalogNumber(dynamic value) {
  if (value is num) return value.isFinite ? value : 0;
  return num.tryParse(
        value?.toString().replaceAll(RegExp(r'[^0-9.-]'), '') ?? '',
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

/// Returns an optimized Cloudinary delivery URL.
///
/// Firestore continues to store the original upload URL. Cloudinary creates and
/// caches this smaller delivery version automatically when the app displays it.
String optimizedCloudinaryImageUrl(String url, {int width = 800, int? height}) {
  final originalUrl = url.trim();
  const uploadMarker = '/image/upload/';

  if (!originalUrl.contains('res.cloudinary.com') ||
      !originalUrl.contains(uploadMarker)) {
    return originalUrl;
  }

  final afterUpload = originalUrl.substring(
    originalUrl.indexOf(uploadMarker) + uploadMarker.length,
  );

  // Do not add the same optimization twice.
  if (afterUpload.startsWith('c_limit,') &&
      afterUpload.contains('/q_auto/f_auto/')) {
    return originalUrl;
  }

  final sizeTransform = height == null
      ? 'c_limit,w_$width'
      : 'c_limit,w_$width,h_$height';

  return originalUrl.replaceFirst(
    uploadMarker,
    '$uploadMarker$sizeTransform/q_auto/f_auto/',
  );
}

double? _safeImageDimension(double? value) {
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

int _deliveryWidth(double? value, {required int fallback}) =>
    value == null ? fallback : (value * 2).round();

int? _decodeDimension(double? value) =>
    value == null ? null : (value * 2).round();

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
  data['status'] = raw['status'] == 'Out of Stock'
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

// Each mounted catalog observes Firestore and cancels listeners on disposal.
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
    if (sellerProductsOnly) {
      query = query.where('sellerId', isEqualTo: uid);
    }

    _productSubscription = query.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final items = snapshot.docs.map(catalogProduct).toList()
          ..sort(
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
        if (!mounted) return;
        setState(() {
          catalogProducts = [];
          catalogLoading = false;
          catalogFailure = catalogError(error);
        });
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
            if (!mounted) return;
            setState(() {
              catalogCategories = [];
              catalogCategoryItems = [];
              categoryFailure = catalogError(error);
            });
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
  final displayWidth = _safeImageDimension(width);
  final displayHeight = _safeImageDimension(height);

  Widget placeholder() => Container(
    width: displayWidth,
    height: displayHeight,
    color: const Color(0xFFF7F8FA),
    child: const Center(
      child: Icon(Icons.inventory_2_outlined, color: Color(0xFF0052FF)),
    ),
  );

  if (url.trim().isEmpty) return placeholder();

  final requestedWidth = _deliveryWidth(displayWidth, fallback: 800);
  final requestedHeight = _decodeDimension(displayHeight);

  return Image.network(
    optimizedCloudinaryImageUrl(
      url,
      width: requestedWidth,
      height: requestedHeight,
    ),
    width: displayWidth,
    height: displayHeight,
    fit: BoxFit.cover,
    cacheWidth: _decodeDimension(displayWidth),
    cacheHeight: requestedHeight,
    loadingBuilder: (context, child, loadingProgress) {
      return loadingProgress == null ? child : placeholder();
    },
    errorBuilder: (_, __, ___) => placeholder(),
  );
}

Widget catalogCategoryImage(
  String imageUrl, {
  double? width,
  double? height,
  IconData fallbackIcon = Icons.category_outlined,
}) {
  final displayWidth = _safeImageDimension(width);
  final displayHeight = _safeImageDimension(height);

  Widget placeholder() => Container(
    width: displayWidth,
    height: displayHeight,
    color: const Color(0xFFEBF2FF),
    child: Center(child: Icon(fallbackIcon, color: const Color(0xFF0052FF))),
  );

  if (imageUrl.trim().isEmpty) return placeholder();

  final requestedWidth = _deliveryWidth(displayWidth, fallback: 300);
  final requestedHeight = _decodeDimension(displayHeight);

  return Image.network(
    optimizedCloudinaryImageUrl(
      imageUrl,
      width: requestedWidth,
      height: requestedHeight,
    ),
    width: displayWidth,
    height: displayHeight,
    fit: BoxFit.cover,
    cacheWidth: _decodeDimension(displayWidth),
    cacheHeight: requestedHeight,
    loadingBuilder: (context, child, loadingProgress) {
      return loadingProgress == null ? child : placeholder();
    },
    errorBuilder: (_, __, ___) => placeholder(),
  );
}

void catalogComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature is not connected yet.')));
}
