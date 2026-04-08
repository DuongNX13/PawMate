import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dang nhap')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const TextField(decoration: InputDecoration(labelText: 'Email')),
          const SizedBox(height: 16),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Mat khau'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/pets'),
            child: const Text('Dang nhap'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Dang nhap voi Google'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Dang nhap voi Apple'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/auth/register'),
            child: const Text('Tao tai khoan'),
          ),
        ],
      ),
    );
  }
}
