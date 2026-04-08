import 'package:flutter/material.dart';

class CreatePetScreen extends StatelessWidget {
  const CreatePetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tao ho so thu cung')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          TextField(decoration: InputDecoration(labelText: 'Ten')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Loai')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Giong')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Ngay sinh')),
        ],
      ),
    );
  }
}
