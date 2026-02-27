import 'package:flutter/material.dart';

class UserManagerPage extends StatelessWidget {
  const UserManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Manager'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/admin-home'),
        ),
      ),
      body: const Center(
        child: Text('User management coming soon — list users, create, edit, roles.'),
      ),
    );
  }
}
