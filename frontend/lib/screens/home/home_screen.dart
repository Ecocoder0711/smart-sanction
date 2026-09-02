import 'package:flutter/material.dart';

import '../../models/scheme.dart';
import '../../services/api_service.dart';
import '../scheme_matching/scheme_matching_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Scheme>> _schemesFuture;

  @override
  void initState() {
    super.initState();
    _schemesFuture = _apiService.fetchSchemes();
  }

  void _retry() {
    setState(() {
      _schemesFuture = _apiService.fetchSchemes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMART-SANCTION'),
      ),
      body: FutureBuilder<List<Scheme>>(
        future: _schemesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final schemes = snapshot.data ?? const <Scheme>[];

          if (schemes.isEmpty) {
            return const Center(child: Text('No schemes available'));
          }

          return ListView.builder(
            itemCount: schemes.length,
            itemBuilder: (context, index) {
              final scheme = schemes[index];
              return Card(
                child: ListTile(
                  title: Text(scheme.name),
                  subtitle: Text(
                    '${scheme.category} • ${scheme.interestRate}% interest',
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SchemeMatchingScreen(),
            ),
          );
        },
        child: const Icon(Icons.search),
      ),
    );
  }
}
