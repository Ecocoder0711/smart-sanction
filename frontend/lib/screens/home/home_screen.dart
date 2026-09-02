import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMART-SANCTION'),
      ),
      body: const Center(
        child: Text('Theme Initialized'),
      ),
    );
  }
}
