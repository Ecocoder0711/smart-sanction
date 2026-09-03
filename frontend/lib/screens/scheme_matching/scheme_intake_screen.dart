import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_error_messages.dart';
import '../../core/network/request_formatting.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../wizard/login_screen.dart';
import 'matched_schemes_screen.dart';

class SchemeIntakeScreen extends StatefulWidget {
  const SchemeIntakeScreen({super.key});

  @override
  State<SchemeIntakeScreen> createState() => _SchemeIntakeScreenState();
}

class _SchemeIntakeScreenState extends State<SchemeIntakeScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _progressTrackColor = Color(0xFFD9E3F4);

  static const List<String> _incomeKeys = [
    'income_under_50k',
    'income_50k_1lakh',
    'income_1lakh_2_5lakh',
    'income_2_5lakh_5lakh',
    'income_above_5lakh',
  ];

  static const List<String> _purposeKeys = [
    'purpose_education',
    'purpose_business',
    'purpose_agriculture',
    'purpose_housing',
    'purpose_other',
  ];

  static const List<String> _categories = ['SC', 'ST', 'OBC', 'General'];

  /// This flow does not collect a tenure, so it uses the backend default.
  /// The EMI Calculator is integrated separately and may differ.
  static const int _tenureMonths = 60;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _apiService = ApiService();

  String? _selectedIncomeKey;
  String? _selectedPurposeKey;
  String? _selectedCategory;
  String? _categoryError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({String? hintText, String? prefixText}) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
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

  Widget _categoryOption(String value) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = value;
          _categoryError = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.deepNavy : _borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected ? AppColors.deepNavy : _borderColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              'scheme_matching.category_${value.toLowerCase()}'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    // Validation is unchanged: the same four checks and the same inline
    // category error.
    final isFormValid = _formKey.currentState!.validate();
    final isIncomeValid = _selectedIncomeKey != null;
    final isPurposeValid = _selectedPurposeKey != null;
    final isCategoryValid = _selectedCategory != null;

    setState(() {
      _categoryError = isCategoryValid
          ? null
          : 'scheme_matching.category_error'.tr();
    });

    if (!isFormValid || !isIncomeValid || !isPurposeValid || !isCategoryValid) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) {
      await _returnToLogin();
      return;
    }

    // Only the amount and tenure are sent. The income bucket, category and
    // purpose above stay display-only on purpose: the backend matches against
    // the exact annual_income/category/gender already stored on the profile,
    // and turning a bucket like "1-2.5 lakh" into a number would be invented
    // data feeding real eligibility and ML. "purpose" has no backend field.
    final requestedAmount = roundToPaise(
      double.parse(_amountController.text.trim()),
    );

    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.fetchMatches(
        requestedAmount: requestedAmount,
        tenureMonths: _tenureMonths,
        token: token,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchedSchemesScreen(
            candidates: result.candidates,
            mlStatus: result.mlStatus,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      if (isUnauthorized(error)) {
        await _returnToLogin();
        return;
      }
      _showError(
        describeApiError(error, fallbackKey: 'scheme_matching.match_failed'),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Sends an expired session back to Login rather than to an empty result.
  Future<void> _returnToLogin() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    _showError('auth.session_expired'.tr());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
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
                        'scheme_matching.intake_step_label'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'scheme_matching.intake_header_label'.tr(),
                        style: const TextStyle(
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
                    child: const LinearProgressIndicator(
                      value: 0.25,
                      minHeight: 8,
                      backgroundColor: _progressTrackColor,
                      valueColor: AlwaysStoppedAnimation(
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
                          Text(
                            'scheme_matching.intake_title'.tr(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'scheme_matching.intake_subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'scheme_matching.annual_income_label'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedIncomeKey,
                            isExpanded: true,
                            decoration: _fieldDecoration(),
                            hint: Text(
                              'scheme_matching.annual_income_placeholder'.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: _incomeKeys
                                .map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Text(
                                      'scheme_matching.$key'.tr(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedIncomeKey = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'scheme_matching.income_error'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'scheme_matching.purpose_label'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedPurposeKey,
                            isExpanded: true,
                            decoration: _fieldDecoration(),
                            hint: Text(
                              'scheme_matching.purpose_placeholder'.tr(),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: _purposeKeys
                                .map(
                                  (key) => DropdownMenuItem(
                                    value: key,
                                    child: Text(
                                      'scheme_matching.$key'.tr(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedPurposeKey = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'scheme_matching.purpose_error'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'scheme_matching.estimated_amount_label'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              prefixText: '₹ ',
                              hintText: '0.00',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(value ?? '');
                              if (amount == null || amount <= 0) {
                                return 'scheme_matching.amount_error'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'scheme_matching.social_category_label'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _categoryOption(_categories[0])),
                              const SizedBox(width: 12),
                              Expanded(child: _categoryOption(_categories[1])),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _categoryOption(_categories[2])),
                              const SizedBox(width: 12),
                              Expanded(child: _categoryOption(_categories[3])),
                            ],
                          ),
                          if (_categoryError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _categoryError!,
                              style: const TextStyle(
                                color: AppColors.errorRed,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              // Disabled while the request is in flight so a
                              // second tap cannot submit twice.
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'scheme_matching.find_schemes_button'.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Swaps in place of the search icon, at the
                                  // same 20px box, so the button does not
                                  // change size or reflow while loading.
                                  if (_isSubmitting)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.search, size: 20),
                                ],
                              ),
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
        ),
      ),
    );
  }
}
