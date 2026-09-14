import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EstimateService {
  static final db = FirebaseFirestore.instance;
  static String get uid {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id == null) throw StateError('Please sign in as an approved Buyer.');
    return id;
  }

  static CollectionReference<Map<String, dynamic>> cart(String buyerId) =>
      db.collection('carts').doc(buyerId).collection('items');
  static String text(dynamic value) => value?.toString() ?? '';
  static int paise(dynamic price) {
    if (price is! num || !price.isFinite || price < 0) {
      throw StateError(
        'A product has an invalid price. Please contact support.',
      );
    }
    return (price * 100).round();
  }

  static String money(int value) => '₹${(value / 100).toStringAsFixed(2)}';
  static String date(dynamic value) => value is Timestamp
      ? value.toDate().toLocal().toString().substring(0, 19)
      : 'Saving…';
  static String error(Object e) => e is StateError
      ? text(e.message)
      : e is FirebaseException && e.code == 'permission-denied'
      ? 'Access denied. Check your Buyer approval and publish the updated Firestore rules.'
      : 'Could not complete the request. Check your connection and try again.';
  static void checkBuyer(Map<String, dynamic>? profile) {
    if (profile?['userType'] != 'Buyer' ||
        profile?['accountStatus'] != 'approved') {
      throw StateError('This function is only for approved Buyers.');
    }
  }

  static void checkProduct(Map<String, dynamic>? p) {
    if (p == null ||
        p['status'] != 'Approved' ||
        p['isActive'] != true ||
        p['inStock'] != true ||
        p['stockStatus'] != 'In Stock') {
      throw StateError(
        'A product is inactive or out of stock. Remove it before checkout.',
      );
    }
  }

  static int minimum(Map<String, dynamic> p) {
    final n = p['minOrderQuantity'];
    if (n is! int || n < 1 || n > 1000000)
      throw StateError('Invalid minimum order quantity.');
    return n;
  }

  static Future<void> addProduct(String productId) async {
    final buyerId = uid;
    await db.runTransaction((tx) async {
      final profile = await tx.get(db.collection('users').doc(buyerId));
      final product = await tx.get(db.collection('products').doc(productId));
      final ref = cart(buyerId).doc(productId);
      final existing = await tx.get(ref);
      checkBuyer(profile.data());
      checkProduct(product.data());
      final moq = minimum(product.data()!);
      final old = existing.data()?['quantity'];
      // Repeated Add to Cart keeps an existing quantity; it does not duplicate a row.
      final quantity = old is int && old >= moq ? old : moq;
      tx.set(ref, {
        'productId': productId,
        'quantity': quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> changeQuantity(String productId, int delta) async {
    final buyerId = uid;
    await db.runTransaction((tx) async {
      final ref = cart(buyerId).doc(productId);
      final item = await tx.get(ref);
      final product = await tx.get(db.collection('products').doc(productId));
      if (!item.exists)
        throw StateError('This item was removed from your cart.');
      checkProduct(product.data());
      final moq = minimum(product.data()!);
      final old = item.data()!['quantity'] as int;
      final next = old < moq ? moq : old + delta;
      if (next < moq)
        throw StateError('Minimum quantity for this product is $moq.');
      if (next > 1000000) throw StateError('Maximum quantity is 1,000,000.');
      tx.update(ref, {
        'quantity': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<List<Map<String, dynamic>>> loadCart(String buyerId) async {
    final profile = await db
        .collection('users')
        .doc(buyerId)
        .get(const GetOptions(source: Source.server));
    checkBuyer(profile.data());
    final docs = await cart(
      buyerId,
    ).get(const GetOptions(source: Source.server));
    return hydrate(docs.docs);
  }

  static Future<List<Map<String, dynamic>>> hydrate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final result = <Map<String, dynamic>>[];
    final shopMinimums = <String, int>{};
    for (final doc in docs) {
      final product = await db
          .collection('products')
          .doc(doc.id)
          .get(const GetOptions(source: Source.server));
      final p = product.data() ?? <String, dynamic>{};
      final seller = text(p['sellerId']);
      if (seller.isNotEmpty && !shopMinimums.containsKey(seller)) {
        final setting = await db
            .collection('shop_settings')
            .doc(seller)
            .get(const GetOptions(source: Source.server));
        shopMinimums[seller] = paise(
          setting.data()?['minimumPurchaseAmount'] ?? 0,
        );
      }
      final price = p['sellingPrice'];
      final priceValid = price is num && price.isFinite && price >= 0;
      result.add({
        'id': doc.id,
        'title': text(p['productName']).isEmpty
            ? 'Unavailable product'
            : text(p['productName']),
        'color': text(p['unitTypes']),
        'variant': text(p['unitTypes']),
        'price': priceValid ? paise(price) / 100 : 0.0,
        'pricePaise': priceValid ? paise(price) : 0,
        'quantity': doc.data()['quantity'] as int,
        'minimumQuantity': p['minOrderQuantity'] is int
            ? p['minOrderQuantity']
            : 1,
        'sellerId': seller,
        'shopName': text(p['sellerShopName']),
        'imageUrl': text(p['frontImage']),
        'minimumPaise': shopMinimums[seller] ?? 0,
        'available':
            priceValid &&
            p['isActive'] == true &&
            p['status'] == 'Approved' &&
            p['inStock'] == true,
        'isSelected': true,
      });
    }
    return result;
  }

  static Map<String, List<Map<String, dynamic>>> group(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      groups.putIfAbsent(item['sellerId'] as String, () => []).add(item);
    }
    return groups;
  }

  static int total(List<Map<String, dynamic>> items) => items.fold<int>(
    0,
    (sum, item) =>
        sum + (item['pricePaise'] as int) * (item['quantity'] as int),
  );
  static void validate(List<Map<String, dynamic>> items) {
    if (items.isEmpty) throw StateError('Your cart is empty.');
    for (final item in items) {
      if (item['available'] != true)
        throw StateError('${item['title']} is unavailable. Please remove it.');
      if ((item['quantity'] as int) < (item['minimumQuantity'] as int)) {
        throw StateError(
          'Update ${item['title']} to its minimum quantity of ${item['minimumQuantity']}.',
        );
      }
    }
    for (final entries in group(items).values) {
      // Each request can be fully validated by Firestore's per-write document-access budget.
      if (entries.length > 8)
        throw StateError(
          'Use up to 8 different products per seller in one estimate.',
        );
      if (total(entries) < (entries.first['minimumPaise'] as int)) {
        throw StateError(
          '${entries.first['shopName']}: minimum purchase is ${money(entries.first['minimumPaise'] as int)}.',
        );
      }
    }
  }

  static Future<void> submitSeller({
    required String buyerId,
    required String estimateId,
    required List<Map<String, dynamic>> preview,
  }) async {
    if (uid != buyerId) throw StateError('Account changed. Reopen checkout.');
    final sellerId = preview.first['sellerId'] as String;
    final ref = db.collection('estimated_orders').doc(estimateId);
    await db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists)
        return; // Same checkout retry cannot create another estimate.
      final user = await tx.get(db.collection('users').doc(buyerId));
      checkBuyer(user.data());
      final buyer = user.data()!;
      final settings = await tx.get(
        db.collection('shop_settings').doc(sellerId),
      );
      final minPaise = paise(settings.data()?['minimumPurchaseAmount'] ?? 0);
      final lines = <Map<String, dynamic>>[];
      final cartRefs = <DocumentReference<Map<String, dynamic>>>[];
      for (final item in preview) {
        final id = item['id'] as String;
        final cartRef = cart(buyerId).doc(id);
        final cartItem = await tx.get(cartRef);
        final product = await tx.get(db.collection('products').doc(id));
        checkProduct(product.data());
        final p = product.data()!;
        final qty = cartItem.data()?['quantity'];
        if (qty is! int ||
            qty != item['quantity'] ||
            p['sellerId'] != sellerId ||
            paise(p['sellingPrice']) != item['pricePaise'] ||
            qty < minimum(p)) {
          throw StateError(
            'Cart, price or minimum quantity changed. Go back and refresh your cart.',
          );
        }
        lines.add({
          'productId': id,
          'name': text(p['productName']),
          'qty': qty,
          'unitPricePaise': paise(p['sellingPrice']),
          'unitTypes': text(p['unitTypes']),
          'imageUrl': text(p['frontImage']),
          'sellerShopName': text(p['sellerShopName']),
        });
        cartRefs.add(cartRef);
      }
      final totalPaise = lines.fold<int>(
        0,
        (sum, line) =>
            sum + (line['qty'] as int) * (line['unitPricePaise'] as int),
      );
      if (totalPaise < minPaise)
        throw StateError(
          'This seller now requires ${money(minPaise)}. Refresh your cart.',
        );
      tx.set(ref, {
        'buyerId': buyerId,
        'buyerFirstName': text(buyer['firstName']),
        'buyerLastName': text(buyer['lastName']),
        'buyerMobile': text(buyer['mobileNumber']),
        'buyerEmail': text(buyer['email']),
        'buyerAddress': text(buyer['shopAddress']),
        'buyerShopName': text(buyer['shopName']),
        'sellerId': sellerId,
        'shopName': lines.first['sellerShopName'],
        'items': lines,
        'productIds': lines.map((line) => line['productId']).toList(),
        'totalPaise': totalPaise,
        'minimumPaise': minPaise,
        'status': 'Pending Approval',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': buyerId,
      });
      for (final cartRef in cartRefs) {
        tx.delete(cartRef);
      }
    });
  }

  static Future<void> status(String id, String value) async {
    final actor = uid;
    final ref = db.collection('estimated_orders').doc(id);
    final event = ref.collection('activity').doc();
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Estimate no longer exists.');
      if (doc.data()!['status'] == value) return;
      tx.update(ref, {
        'status': value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor,
      });
      tx.set(event, {
        'status': value,
        'previousStatus': doc.data()!['status'],
        'updatedBy': actor,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
