// File: lib/wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/signup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return UserStatusChecker(uid: snapshot.data!.uid);
        }

        return const SignUpScreen();
      },
    );
  }
}

class UserStatusChecker extends StatelessWidget {
  final String uid;
  const UserStatusChecker({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User record not found.')),
          );
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String status = userData['status'] ?? 'Pending';
        String role = userData['role'] ?? 'User';

        if (role == 'Admin') {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Panel')),
            body: const Center(child: Text('Admin Dashboard')),
          );
        }

        if (status == 'Approved') {
          return Scaffold(
            appBar: AppBar(
              title: Text('${userData['userType'] ?? "User"} Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
            body: Center(
              child: Text(
                'Welcome, ${userData['firstName']}! You are approved.',
              ),
            ),
          );
        } else if (status == 'Rejected') {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Account Rejected',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your application was rejected by the admin.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        } else {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_top,
                    size: 80,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Approval Pending',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Your account is waiting for admin approval.'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
