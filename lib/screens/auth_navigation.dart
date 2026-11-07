import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'home_screen.dart';
import 'home_screen_two.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class MissingUserProfile implements Exception {}

/// Errors that may be temporary network/backend problems.
bool isTemporaryConnectionError(Object error) {
  if (error is FirebaseException) {
    return [
      'unavailable',
      'deadline-exceeded',
      'network-request-failed',
    ].contains(error.code);
  }
  return false;
}

/// Checks whether the account is allowed to enter the application.
String? accessProblem(Map<String, dynamic>? data) {
  if (data == null) {
    return 'Your account profile is incomplete.';
  }

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

/// Opens the correct dashboard.
///
/// allowCachedProfileOnNetworkError should be true when called from
/// SplashScreen. Login uses the default false value and checks the server.
Future<void> openRoleHome(
  BuildContext context, {
  bool allowCachedProfileOnNetworkError = false,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw const FormatException('Please sign in again.');
  }

  final userDocument = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);

  DocumentSnapshot<Map<String, dynamic>> profile;

  try {
    // Always try to get the latest account status first.
    profile = await userDocument.get(const GetOptions(source: Source.server));
  } on FirebaseException catch (error) {
    // Only use cached data for temporary connection failures.
    if (!allowCachedProfileOnNetworkError ||
        !isTemporaryConnectionError(error)) {
      rethrow;
    }

    profile = await userDocument.get(const GetOptions(source: Source.cache));
  }

  final data = profile.data();

  if (data == null) {
    throw MissingUserProfile();
  }

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

// Keeps watching the account while the user is inside the application.
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
            // Cached snapshots are useful for offline startup, but they
            // cannot confirm a new approval/status change.
            if (snapshot.metadata.isFromCache) return;

            final data = snapshot.data();
            final problem = accessProblem(data);

            if (problem != null || data?['userType'] != widget.role) {
              _close(problem ?? 'Your role has changed. Please log in again.');
            }
          },
          onError: (Object error) {
            // Do not log out just because the network is temporarily down.
            if (isTemporaryConnectionError(error)) return;

            _close(
              'Account access could not be verified. Please log in again.',
            );
          },
        );

    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != widget.uid) {
        _close('You have been signed out.');
      }
    });
  }

  void _close(String message) {
    if (_closing || !mounted) return;

    _closing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {
        // Remove access to the dashboard even if sign-out fails.
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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
  Widget build(BuildContext context) {
    return _closing
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : widget.child;
  }
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
        'account permissions and deployed rules.';
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
}
