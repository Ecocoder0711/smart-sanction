import 'package:flutter/material.dart';

class SchemeMatchingScreen extends StatefulWidget {
  const SchemeMatchingScreen({super.key});

  @override
  State<SchemeMatchingScreen> createState() => _SchemeMatchingScreenState();
}

class _SchemeMatchingScreenState extends State<SchemeMatchingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestedAmountController = TextEditingController();
  final _tenureController = TextEditingController(text: '60');

  @override
  void dispose() {
    _requestedAmountController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User authentication required to process matches'),
        ),
      );
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
                onPressed: _submit,
                child: const Text('Search Schemes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
