import 'dart:convert';
import 'dart:math';

import 'package:firebase_functions/firebase_functions.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

const Duration _recentLoginWindow = Duration(minutes: 5);
const Duration _deletionLockDuration = Duration(hours: 2);

const int _pageSize = 100;

const String _deletedUser = 'Deleted User';
const String _deletedReference = 'deleted';

void main() {
  runFunctions((firebase) {
    firebase.https.onRequest(
      name: 'deleteMyAccount',
      options: const HttpsOptions(maxInstances: Instances(5)),
      (request) async {
        dynamic jobRef;
        String lockToken = '';
        bool authenticationDeleted = false;

        try {
          if (request.method != 'POST') {
            return _jsonResponse(405, {
              'success': false,
              'message': 'Only POST requests are allowed.',
            });
          }

          final authorization = request.headers['authorization'] ?? '';

          if (!authorization.startsWith('Bearer ')) {
            return _jsonResponse(401, {
              'success': false,
              'message': 'Authentication token is missing.',
            });
          }

          final idToken = authorization.substring(7).trim();

          if (idToken.isEmpty) {
            return _jsonResponse(401, {
              'success': false,
              'message': 'Authentication token is invalid.',
            });
          }

          final adminApp = firebase.adminApp;
          final auth = adminApp.auth();

          final decodedToken = await auth.verifyIdToken(
            idToken,
            checkRevoked: true,
          );

          final uid = decodedToken.uid;

          final age = DateTime.now().toUtc().difference(
            decodedToken.authTime.toUtc(),
          );

          if (age.isNegative || age > _recentLoginWindow) {
            return _jsonResponse(401, {
              'success': false,
              'message': 'Please sign in again before deleting your account.',
              'reauthenticationRequired': true,
            });
          }

          final firestore = adminApp.firestore();

          final userRef = firestore.collection('users').doc(uid);

          jobRef = firestore.collection('account_deletion_jobs').doc(uid);

          final jobSnapshot = await jobRef.get();
          final userSnapshot = await userRef.get();

          final userData = userSnapshot.data() ?? <String, dynamic>{};
          final jobData = jobSnapshot.data() ?? <String, dynamic>{};

          String role;

          if (userSnapshot.exists) {
            role = (userData['userType'] ?? '').toString().trim().toLowerCase();
          } else if (jobSnapshot.exists) {
            role = (jobData['role'] ?? '').toString().trim().toLowerCase();
          } else {
            return _jsonResponse(404, {
              'success': false,
              'message': 'User profile was not found.',
            });
          }

          if (role == 'admin') {
            return _jsonResponse(403, {
              'success': false,
              'message': 'Admin accounts cannot be deleted here.',
            });
          }

          if (role != 'buyer' && role != 'seller') {
            return _jsonResponse(403, {
              'success': false,
              'message': 'This account type cannot use self-service deletion.',
            });
          }

          if (jobData['status'] == 'completed') {
            return _jsonResponse(200, {
              'success': true,
              'message': 'Account deletion has already been completed.',
            });
          }

          lockToken = _createLockToken(uid);

          final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;

          final lockAcquired = await firestore.runTransaction<bool>((
            transaction,
          ) async {
            final currentJob = await transaction.get(jobRef);

            final currentData = currentJob.data() ?? <String, dynamic>{};

            if (currentData['status'] == 'completed') {
              return false;
            }

            final expiry = currentData['lockExpiresAtMillis'];

            if (currentData['status'] == 'processing' &&
                expiry is num &&
                expiry > nowMillis) {
              return false;
            }

            final now = DateTime.now().toUtc();

            transaction.set(jobRef, <String, Object?>{
              'uid': uid,
              'role': role,
              'status': 'processing',
              'stage': 'started',
              'lockToken': lockToken,
              'lockExpiresAtMillis':
                  now.millisecondsSinceEpoch +
                  _deletionLockDuration.inMilliseconds,
              'updatedAt': now,
              if (!currentJob.exists) 'createdAt': now,
            }, options: SetOptions.merge());

            return true;
          });

          if (!lockAcquired) {
            return _jsonResponse(409, {
              'success': false,
              'message':
                  'Account deletion is already processing or has been completed.',
            });
          }

          Future<void> checkLock() async {
            await _assertLock(jobRef, lockToken);
          }

          Future<void> updateStage(String stage) async {
            await checkLock();

            await jobRef.update({
              'stage': stage,
              'updatedAt': DateTime.now().toUtc(),
            });
          }

          // 1. Remove private Buyer data.
          if (role == 'buyer') {
            await _deleteBuyerPrivateData(firestore, uid, checkLock);
          }

          await updateStage('private_data_processed');

          // 2. Anonymize Buyer business history.
          if (role == 'buyer') {
            await _anonymizeBuyerHistory(firestore, uid, checkLock);
          }

          // 3. Anonymize Seller business history.
          if (role == 'seller') {
            await _anonymizeSellerHistory(firestore, uid, checkLock);

            await checkLock();

            await firestore.collection('shop_settings').doc(uid).delete();

            await _deactivateSellerProducts(firestore, uid, checkLock);
          }

          // 4. Anonymize activity records across known collections.
          await _anonymizeAllUserActivity(firestore, uid, checkLock);

          await updateStage('business_records_processed');

          // 5. Remove the user's product reviews.
          await _deleteUserReviews(firestore, uid, checkLock);

          // 6. Remove the old deletion-request document.
          await checkLock();

          await firestore
              .collection('account_deletion_requests')
              .doc(uid)
              .delete();

          await updateStage('firestore_cleanup_completed');

          // 7. Delete the user profile.
          await checkLock();

          await userRef.delete();

          await updateStage('profile_deleted');

          // 8. Delete the Firebase Authentication account.
          await updateStage('authentication_deletion_started');

          await auth.deleteUser(uid);

          authenticationDeleted = true;

          // Authentication has been deleted.
          // Do not report failure if this final update fails.
          try {
            await jobRef.update({
              'status': 'completed',
              'stage': 'completed',
              'completedAt': DateTime.now().toUtc(),
              'updatedAt': DateTime.now().toUtc(),
              'lockExpiresAtMillis': 0,
              'lockToken': null,
            });
          } catch (completionError) {
            print(
              'Authentication deleted, but completion update failed: '
              '$completionError',
            );
          }

          return _jsonResponse(200, {
            'success': true,
            'message': 'Your account has been deleted successfully.',
          });
        } catch (error, stackTrace) {
          print('Account deletion error: $error');
          print('Account deletion stack trace: $stackTrace');

          if (authenticationDeleted) {
            return _jsonResponse(200, {
              'success': true,
              'message': 'Your account has been deleted successfully.',
            });
          }

          if (jobRef != null && lockToken.isNotEmpty) {
            try {
              await _markDeletionFailed(jobRef, lockToken);
            } catch (jobError) {
              print('Could not update deletion job: $jobError');
            }
          }

          return _jsonResponse(500, {
            'success': false,
            'message':
                'Account deletion could not be completed. Please try again or contact support.',
          });
        }
      },
    );
  });
}

// ------------------------------------------------------------
// LOCK MANAGEMENT
// ------------------------------------------------------------

String _createLockToken(String uid) {
  final random = Random.secure();

  return '${uid}_${DateTime.now().microsecondsSinceEpoch}_'
      '${random.nextInt(1 << 32)}_${random.nextInt(1 << 32)}';
}

Future<void> _assertLock(dynamic jobRef, String token) async {
  final snapshot = await jobRef.get();

  final data = snapshot.data() ?? <String, dynamic>{};

  if (data['lockToken'] != token || data['status'] != 'processing') {
    throw StateError('Deletion lock is no longer owned by this request.');
  }

  final expiry = data['lockExpiresAtMillis'];

  if (expiry is! num ||
      expiry <= DateTime.now().toUtc().millisecondsSinceEpoch) {
    throw StateError('Deletion lock has expired.');
  }
}

Future<void> _markDeletionFailed(dynamic jobRef, String token) async {
  await jobRef.firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(jobRef);

    final data = snapshot.data() ?? <String, dynamic>{};

    if (data['lockToken'] != token || data['status'] != 'processing') {
      return;
    }

    transaction.set(jobRef, <String, Object?>{
      'status': 'failed',
      'stage': data['stage'] ?? 'failed',
      'updatedAt': DateTime.now().toUtc(),
      'lockExpiresAtMillis': 0,
      'lockToken': null,
    }, options: SetOptions.merge());
  });
}

// ------------------------------------------------------------
// PAGINATED QUERY PROCESSING
// ------------------------------------------------------------

// Keep the query's actual Firestore data type all the way through this helper.
// Do not widen Query<DocumentData> to Query<dynamic> or Map<String, Object>:
// doing so can trigger runtime casts of the package's internal converter.
Future<void> _forEachQueryPage(
  Query<DocumentData> baseQuery,
  Future<void> Function(QueryDocumentSnapshot<DocumentData> document) action,
  Future<void> Function() checkLock,
) async {
  QueryDocumentSnapshot<DocumentData>? lastDocument;

  while (true) {
    await checkLock();

    Query<DocumentData> pageQuery = baseQuery.limit(_pageSize);

    if (lastDocument != null) {
      pageQuery = pageQuery.startAfterDocument(lastDocument);
    }

    final snapshot = await pageQuery.get();
    final documents = snapshot.docs;

    if (documents.isEmpty) {
      break;
    }

    for (final document in documents) {
      await checkLock();
      await action(document);
    }

    lastDocument = documents.last;

    if (documents.length < _pageSize) {
      break;
    }
  }
}

// ------------------------------------------------------------
// BUYER PRIVATE DATA
// ------------------------------------------------------------

Future<void> _deleteBuyerPrivateData(
  Firestore firestore,
  String uid,
  Future<void> Function() checkLock,
) async {
  await checkLock();

  await firestore.collection('carts').doc(uid).delete();

  final limitsRef = firestore.collection('buyer_request_limits').doc(uid);

  await _forEachQueryPage(limitsRef.collection('types'), (document) async {
    await document.ref.delete();
  }, checkLock);

  await checkLock();

  await limitsRef.delete();
}

// ------------------------------------------------------------
// BUYER BUSINESS HISTORY
// ------------------------------------------------------------

Future<void> _anonymizeBuyerHistory(
  Firestore firestore,
  String uid,
  Future<void> Function() checkLock,
) async {
  // Enquiries.
  await _forEachQueryPage(
    firestore.collection('enquiries').where('buyerId', WhereFilter.equal, uid),
    (doc) async {
      final data = doc.data();

      final changes = <String, dynamic>{
        'buyerId': _deletedReference,
        'buyerName': _deletedUser,
        'buyerEmail': null,
        'mobileNumber': null,
        'buyerAddress': null,
      };

      if (data['updatedBy'] == uid) {
        changes['updatedBy'] = _deletedReference;
      }

      await doc.ref.update(changes);
      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );

  // Sample requests.
  await _forEachQueryPage(
    firestore
        .collection('sample_requests')
        .where('buyerId', WhereFilter.equal, uid),
    (doc) async {
      final data = doc.data();

      final changes = <String, dynamic>{
        'buyerId': _deletedReference,
        'buyerEmail': null,
        'buyerAddress': null,
        'userName': _deletedUser,
        'userMobile': null,
      };

      if (data['updatedBy'] == uid) {
        changes['updatedBy'] = _deletedReference;
      }

      await doc.ref.update(changes);
      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );

  // Product queries.
  await _forEachQueryPage(
    firestore
        .collection('product_queries')
        .where('buyerId', WhereFilter.equal, uid),
    (doc) async {
      final data = doc.data();

      final changes = <String, dynamic>{
        'buyerId': _deletedReference,
        'buyerName': _deletedUser,
        'buyerEmail': null,
        'mobileNumber': null,
      };

      if (data['updatedBy'] == uid) {
        changes['updatedBy'] = _deletedReference;
      }

      await doc.ref.update(changes);
      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );

  // Estimated orders.
  await _forEachQueryPage(
    firestore
        .collection('estimated_orders')
        .where('buyerId', WhereFilter.equal, uid),
    (doc) async {
      final data = doc.data();

      final changes = <String, dynamic>{
        'buyerId': _deletedReference,
        'buyerFirstName': _deletedUser,
        'buyerLastName': null,
        'buyerEmail': null,
        'buyerMobile': null,
        'buyerAddress': null,
        'buyerShopName': null,
      };

      if (data['updatedBy'] == uid) {
        changes['updatedBy'] = _deletedReference;
      }

      await doc.ref.update(changes);
      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );
}

// ------------------------------------------------------------
// SELLER BUSINESS HISTORY
// ------------------------------------------------------------

Future<void> _anonymizeSellerHistory(
  Firestore firestore,
  String uid,
  Future<void> Function() checkLock,
) async {
  // Sample requests.
  await _forEachQueryPage(
    firestore
        .collection('sample_requests')
        .where('sellerId', WhereFilter.equal, uid),
    (doc) async {
      final data = doc.data();

      final changes = <String, dynamic>{
        'sellerId': _deletedReference,
        'sellerShopName': _deletedUser,
      };

      if (data['updatedBy'] == uid) {
        changes['updatedBy'] = _deletedReference;
      }

      await doc.ref.update(changes);
      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );

  // Estimated orders: each order belongs to one Seller.
  await _forEachQueryPage(
    firestore
        .collection('estimated_orders')
        .where('sellerId', WhereFilter.equal, uid),
    (doc) async {
      final data = doc.data();

      final changes = <String, dynamic>{'sellerId': _deletedReference};

      if (data.containsKey('sellerShopName')) {
        changes['sellerShopName'] = _deletedUser;
      }

      if (data['updatedBy'] == uid) {
        changes['updatedBy'] = _deletedReference;
      }

      final items = data['items'];

      if (items is List) {
        final updatedItems = <dynamic>[];
        var itemsChanged = false;

        for (final item in items) {
          if (item is Map) {
            final itemData = Map<String, dynamic>.from(item);

            if (itemData.containsKey('sellerShopName')) {
              itemData['sellerShopName'] = _deletedUser;
              itemsChanged = true;
            }

            updatedItems.add(itemData);
          } else {
            updatedItems.add(item);
          }
        }

        if (itemsChanged) {
          changes['items'] = updatedItems;
        }
      }

      await doc.ref.update(changes);
      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );

  // Product queries last updated by this Seller.
  await _forEachQueryPage(
    firestore
        .collection('product_queries')
        .where('updatedBy', WhereFilter.equal, uid),
    (doc) async {
      await doc.ref.update({'updatedBy': _deletedReference});

      await _anonymizeActivity(doc.ref, uid, checkLock);
    },
    checkLock,
  );
}

// ------------------------------------------------------------
// ACTIVITY HISTORY
// ------------------------------------------------------------

Future<void> _anonymizeAllUserActivity(
  Firestore firestore,
  String uid,
  Future<void> Function() checkLock,
) async {
  const collections = [
    'enquiries',
    'sample_requests',
    'product_queries',
    'estimated_orders',
  ];

  for (final collectionName in collections) {
    await _forEachQueryPage(firestore.collection(collectionName), (
      parent,
    ) async {
      await _anonymizeActivity(parent.ref, uid, checkLock);
    }, checkLock);
  }
}

Future<void> _anonymizeActivity(
  DocumentReference<DocumentData> parentReference,
  String uid,
  Future<void> Function() checkLock,
) async {
  await _forEachQueryPage(parentReference.collection('activity'), (
    activity,
  ) async {
    final data = activity.data();
    final changes = <String, dynamic>{};

    if (data['senderId'] == uid) {
      changes['senderId'] = _deletedReference;
      changes['sender'] = _deletedUser;
    }

    if (data['updatedBy'] == uid) {
      changes['updatedBy'] = _deletedReference;
    }

    if (changes.isNotEmpty) {
      await activity.ref.update(changes);
    }
  }, checkLock);
}

// ------------------------------------------------------------
// SELLER PRODUCTS
// ------------------------------------------------------------

Future<void> _deactivateSellerProducts(
  Firestore firestore,
  String uid,
  Future<void> Function() checkLock,
) async {
  await _forEachQueryPage(
    firestore.collection('products').where('sellerId', WhereFilter.equal, uid),
    (product) async {
      final data = product.data();

      final changes = <String, dynamic>{
        'sellerId': _deletedReference,
        'isActive': false,
        'status': 'Inactive',
        'updatedAt': DateTime.now().toUtc(),
      };

      if (data.containsKey('name')) {
        changes['name'] = _deletedUser;
      }

      if (data.containsKey('sellerName')) {
        changes['sellerName'] = _deletedUser;
      }

      if (data.containsKey('shopName')) {
        changes['shopName'] = _deletedUser;
      }

      if (data.containsKey('address')) {
        changes['address'] = null;
      }

      if (data.containsKey('sellerAddress')) {
        changes['sellerAddress'] = null;
      }

      // Product details, prices, descriptions, images and stock fields
      // are deliberately preserved.
      await product.ref.update(changes);
    },
    checkLock,
  );
}

// ------------------------------------------------------------
// REVIEWS
// ------------------------------------------------------------

Future<void> _deleteUserReviews(
  Firestore firestore,
  String uid,
  Future<void> Function() checkLock,
) async {
  await _forEachQueryPage(firestore.collection('products'), (product) async {
    await product.ref.collection('reviews').doc(uid).delete();
  }, checkLock);
}

// ------------------------------------------------------------
// HTTP RESPONSE
// ------------------------------------------------------------

Response _jsonResponse(int statusCode, Map<String, dynamic> data) {
  return Response(
    statusCode,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );
}
