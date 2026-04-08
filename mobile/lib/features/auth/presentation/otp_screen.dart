import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xac minh OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TextField(
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Ma OTP',
                hintText: '123456',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/pets'),
              child: const Text('Xac minh'),
            ),
          ],
        ),
      ),
    );
  }
}
