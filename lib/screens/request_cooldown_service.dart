import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestCooldownException implements Exception {
  final String message;

  const RequestCooldownException(this.message);

  @override
  String toString() => message;
}

class RequestCooldownService {
  RequestCooldownService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Duration _cooldown = Duration(hours: 24);

  static DocumentReference<Map<String, dynamic>> _limitRef(
    String buyerId,
    String type,
  ) {
    return _db
        .collection('buyer_request_limits')
        .doc(buyerId)
        .collection('types')
        .doc(type);
  }

  static Future<void> submitEnquiry(Map<String, dynamic> enquiryData) {
    return _submit(
      type: 'enquiry',
      collection: 'enquiries',
      data: enquiryData,
      messageName: 'enquiry',
    );
  }

  static Future<void> submitSample(Map<String, dynamic> sampleData) {
    return _submit(
      type: 'sample',
      collection: 'sample_requests',
      data: sampleData,
      messageName: 'sample request',
    );
  }

  static Future<void> _submit({
    required String type,
    required String collection,
    required Map<String, dynamic> data,
    required String messageName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const RequestCooldownException('Please sign in as a Buyer.');
    }

    final requestRef = _db.collection(collection).doc();
    final limitRef = _limitRef(user.uid, type);

    await _db.runTransaction<void>((transaction) async {
      final limitSnapshot = await transaction.get(limitRef);

      if (limitSnapshot.exists) {
        final lastSubmittedAt = limitSnapshot.data()?['lastSubmittedAt'];

        if (lastSubmittedAt is! Timestamp) {
          throw const RequestCooldownException(
            'Your request time could not be verified. Please contact support.',
          );
        }

        final nextAllowedAt = lastSubmittedAt.toDate().add(_cooldown);

        if (DateTime.now().isBefore(nextAllowedAt)) {
          throw RequestCooldownException(
            'You can submit another $messageName after 24 hours.',
          );
        }
      }

      // Reads are complete before writes.
      transaction.set(requestRef, data);

      transaction.set(limitRef, {
        'requestId': requestRef.id,
        'lastSubmittedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
