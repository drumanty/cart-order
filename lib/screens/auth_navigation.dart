import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'home_screen_two.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class MissingUserProfile implements Exception {}

String? accessProblem(Map<String, dynamic>? data) {
  if (data == null) return 'Your account profile is incomplete.';
  if (!['Buyer', 'Seller', 'Admin'].contains(data['userType'])) {
    return 'Invalid account role. Contact support.';
  }
  return switch (data['accountStatus']) {
    'approved' => null,
    'rejected' => 'Your registration was rejected. Contact support.',
    'suspended' => 'Your account is suspended. Contact support.',
    _ => 'Your account is awaiting admin approval.',
  };
}

Future<void> openRoleHome(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw const FormatException('Please sign in again.');
  final profile = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get(const GetOptions(source: Source.server));
  final data = profile.data();
  if (data == null) throw MissingUserProfile();
  final problem = accessProblem(data);
  if (problem != null) {
    await FirebaseAuth.instance.signOut();
    throw FormatException(problem);
  }
  final role = data['userType'] as String;
  final Widget home = switch (role) {
    'Buyer' => const HomeScreen(),
    'Seller' => const HomeScreenTwo(),
    'Admin' => const AdminDashboardScreen(),
    _ => throw const FormatException('Invalid role.'),
  };
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => ApprovalSession(uid: user.uid, role: role, child: home),
    ),
    (_) => false,
  );
}

// This stays mounted under routes pushed by a home screen and clears the entire
// root navigation stack when approval is revoked, role changes or logout occurs.
class ApprovalSession extends StatefulWidget {
  const ApprovalSession({
    super.key,
    required this.uid,
    required this.role,
    required this.child,
  });
  final String uid;
  final String role;
  final Widget child;
  @override
  State<ApprovalSession> createState() => _ApprovalSessionState();
}

class _ApprovalSessionState extends State<ApprovalSession> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  StreamSubscription<User?>? _auth;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _profile = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (snapshot.metadata.isFromCache) return;
            final data = snapshot.data();
            final problem = accessProblem(data);
            if (problem != null || data?['userType'] != widget.role) {
              _close(problem ?? 'Your role has changed. Please log in again.');
            }
          },
          onError: (Object error) {
            _close(
              'Account access could not be verified. Please log in again.',
            );
          },
        );
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != widget.uid) _close('You have been signed out.');
    });
  }

  void _close(String message) {
    if (_closing || !mounted) return;
    _closing = true;
    // Avoid navigation during a build, and do not leave home visible on failure.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // Still remove access to the home UI if sign-out fails.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
    setState(() {});
  }

  @override
  void dispose() {
    _profile?.cancel();
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _closing
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : widget.child;
}

void showAuthError(BuildContext context, Object error) {
  String message = 'Could not finish. Check your connection and retry.';
  if (error is FormatException) {
    message = error.message;
  } else if (error is FirebaseAuthException) {
    message = switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'weak-password' => 'Password does not meet the project password policy.',
      'email-already-in-use' =>
        'This email already has an account. Please log in.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'operation-not-allowed' =>
        'Enable Email/Password in Firebase Authentication.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Check your internet connection and retry.',
      _ => 'Authentication failed (${error.code}). Please retry.',
    };
  } else if (error is FirebaseException) {
    message =
        'Database request failed (${error.code}). Check your connection, '
        'account permissions and deployed rules. For incomplete signup, retry '
        'with the same email and password.';
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
