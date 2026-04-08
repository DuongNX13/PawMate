import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tao tai khoan')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Email')),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(labelText: 'So dien thoai'),
          ),
          const SizedBox(height: 16),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Mat khau'),
          ),
          const SizedBox(height: 16),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Xac nhan mat khau'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/auth/otp'),
            child: const Text('Tao tai khoan'),
          ),
        ],
      ),
    );
  }
}
