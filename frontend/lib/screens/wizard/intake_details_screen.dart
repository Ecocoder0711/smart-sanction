import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../auth/widgets/trust_footer.dart';
import '../scheme_matching/match_results_screen.dart';

class IntakeDetailsScreen extends StatefulWidget {
  const IntakeDetailsScreen({super.key});

  @override
  State<IntakeDetailsScreen> createState() => _IntakeDetailsScreenState();
}

class _IntakeDetailsScreenState extends State<IntakeDetailsScreen> {
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const List<String> _categories = [
    'SC',
    'ST',
    'OBC',
    'General',
    'Women',
    'Minority',
  ];

  static const Map<String, String> _incomeRanges = {
    'under_50k': 'Under ₹50,000',
    '50k_to_1lakh': '₹50,000 - ₹1,00,000',
    '1lakh_to_2.5lakh': '₹1,00,000 - ₹2,50,000',
    '2.5lakh_to_5lakh': '₹2,50,000 - ₹5,00,000',
    'above_5lakh': 'Above ₹5,00,000',
  };

  static const Map<String, String> _purposes = {
    'education': 'Education',
    'business': 'Business / Entrepreneurship',
    'agriculture': 'Agriculture',
    'housing': 'Housing',
    'other': 'Other',
  };

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _apiService = ApiService();

  String? _selectedIncomeRange;
  String? _selectedPurpose;
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.softGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.deepNavy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.errorRed),
      ),
    );
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

    final requestedAmount = double.parse(_amountController.text);

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.fetchMatches(
        requestedAmount: requestedAmount,
        tenureMonths: 60,
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
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
          ),
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
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text('Financial Assistance Portal'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step 2 of 5',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Text(
                          'Intake Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: 0.4,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFD9E3F4),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.emeraldGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Tell us about your needs',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please provide some basic financial information '
                              'so we can match you with the right schemes.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Annual Income',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedIncomeRange,
                              decoration: _fieldDecoration(),
                              hint: const Text('Select your income range'),
                              items: _incomeRanges.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedIncomeRange = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Select your income range';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Purpose of Assistance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPurpose,
                              decoration: _fieldDecoration(),
                              hint: const Text('Select primary purpose'),
                              items: _purposes.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedPurpose = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Select the primary purpose';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Estimated Amount Needed (₹)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: _fieldDecoration().copyWith(
                                prefixText: '₹ ',
                                hintText: '0.00',
                              ),
                              validator: (value) {
                                final amount = double.tryParse(value ?? '');
                                if (amount == null || amount <= 0) {
                                  return 'Enter an amount greater than 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Social Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((category) {
                                final isSelected =
                                    _selectedCategory == category;
                                return ChoiceChip(
                                  label: Text(category),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(
                                      () => _selectedCategory = category,
                                    );
                                  },
                                  backgroundColor: AppColors.softGray,
                                  selectedColor: AppColors.deepNavy
                                      .withValues(alpha: 0.1),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.deepNavy
                                        : _borderColor,
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? AppColors.deepNavy
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emeraldGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.search),
                                label: const Text('Find My Schemes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const TrustFooter(),
          ],
        ),
      ),
    );
  }
}
