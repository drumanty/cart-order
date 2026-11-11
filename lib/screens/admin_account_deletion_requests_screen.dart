import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminAccountDeletionRequestsScreen extends StatefulWidget {
  const AdminAccountDeletionRequestsScreen({super.key});

  @override
  State<AdminAccountDeletionRequestsScreen> createState() =>
      _AdminAccountDeletionRequestsScreenState();
}

class _AdminAccountDeletionRequestsScreenState
    extends State<AdminAccountDeletionRequestsScreen> {
  final Set<String> _processing = {};
  final CollectionReference<Map<String, dynamic>> _requests =
      FirebaseFirestore.instance.collection('account_deletion_requests');

  Future<void> _reviewRequest({
    required String uid,
    required bool approve,
  }) async {
    if (_processing.contains(uid)) return;

    final action = approve ? 'approve' : 'reject';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Approve deletion request?' : 'Reject deletion request?'),
        content: Text(
          approve
              ? 'This will deactivate the user profile and block normal app access. You must then complete the actual account/data deletion manually in Firebase Console, retaining only records you are legally required to keep.'
              : 'The account will remain active, and the user will be allowed to submit another deletion request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.redAccent : Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin session not found. Please log in again.')),
      );
      return;
    }

    setState(() => _processing.add(uid));
    try {
      final batch = FirebaseFirestore.instance.batch();
      final requestRef = _requests.doc(uid);
      batch.update(requestRef, {
        'status': approve ? 'approved_for_deletion' : 'rejected',
        'reviewedBy': admin.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (approve) {
        batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
          'accountStatus': 'deactivated',
          'deactivatedBy': admin.uid,
          'deactivatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve
            ? 'Request approved. Account access is deactivated; complete data deletion next.'
            : 'Request rejected. The account remains active.')),
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not $action request (${error.code}).')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not $action request. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(uid));
    }
  }

  String _dateText(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      return '$d/$m/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Date unavailable';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Account Deletion Requests'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Unable to load requests. Check Admin permissions and Firestore Rules.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final at = a.data()['requestedAt'];
              final bt = b.data()['requestedAt'];
              final ad = at is Timestamp ? at : Timestamp(0, 0);
              final bd = bt is Timestamp ? bt : Timestamp(0, 0);
              return bd.compareTo(ad);
            });

          if (docs.isEmpty) {
            return const Center(child: Text('No account deletion requests.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final uid = doc.id;
              final status = (data['status'] ?? 'pending').toString();
              final email = (data['email'] ?? 'No email').toString();
              final userType = (data['userType'] ?? 'Unknown').toString();
              final pending = status == 'pending';
              final approved = status == 'approved_for_deletion';
              final statusColor = pending
                  ? Colors.orange
                  : approved
                      ? Colors.deepOrange
                      : Colors.redAccent;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Account type: $userType'),
                      const SizedBox(height: 4),
                      Text('Requested: ${_dateText(data['requestedAt'])}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('User ID: $uid',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      if (pending) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _processing.contains(uid)
                                    ? null
                                    : () => _reviewRequest(uid: uid, approve: false),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _processing.contains(uid)
                                    ? null
                                    : () => _reviewRequest(uid: uid, approve: true),
                                child: _processing.contains(uid)
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ] else if (approved) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Next required step: complete deletion of this user’s Firebase Authentication account and non-retained personal data. Do not treat deactivation as completed deletion.',
                          style: TextStyle(color: Colors.deepOrange, fontSize: 12, height: 1.35),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        const Text('The account remains active. The user may submit a new request.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
