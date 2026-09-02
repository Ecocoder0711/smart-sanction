import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'match_results_screen.dart';

class SchemeMatchingScreen extends StatefulWidget {
  const SchemeMatchingScreen({super.key});

  @override
  State<SchemeMatchingScreen> createState() => _SchemeMatchingScreenState();
}

class _SchemeMatchingScreenState extends State<SchemeMatchingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestedAmountController = TextEditingController();
  final _tenureController = TextEditingController(text: '60');
  final _apiService = ApiService();

  bool _isLoading = false;

  @override
  void dispose() {
    _requestedAmountController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User authentication required to process matches'),
        ),
      );
      _goToLogin();
      return;
    }

    final requestedAmount = double.parse(_requestedAmountController.text);
    final tenureText = _tenureController.text.trim();
    final tenureMonths = tenureText.isEmpty ? 60 : int.parse(tenureText);

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.fetchMatches(
        requestedAmount: requestedAmount,
        tenureMonths: tenureMonths,
        token: token,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MatchResultsScreen(candidates: result.candidates),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        await authProvider.logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        _goToLogin();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Matches'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _requestedAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Requested Loan Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requested amount is required';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter an amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tenureController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tenure (Months)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final tenure = int.tryParse(value);
                  if (tenure == null || tenure <= 0) {
                    return 'Enter a valid tenure in months';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search Schemes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
