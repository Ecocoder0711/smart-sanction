import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../auth/widgets/trust_footer.dart';

class _CategoryOption {
  const _CategoryOption(this.value, this.labelKey);

  final String value;
  final String labelKey;
}

class EligibilityScreen extends StatefulWidget {
  const EligibilityScreen({super.key});

  @override
  State<EligibilityScreen> createState() => _EligibilityScreenState();
}

class _EligibilityScreenState extends State<EligibilityScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _progressTrackColor = Color(0xFFD9E3F4);

  // Static placeholder lists — no backend source for state/district exists
  // yet, so these are UI-only pending a real data source.
  static const List<String> _states = [
    'Andhra Pradesh',
    'Bihar',
    'Delhi',
    'Gujarat',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Uttar Pradesh',
    'West Bengal',
  ];

  static const List<String> _districts = [
    'District 1',
    'District 2',
    'District 3',
    'District 4',
  ];

  static const List<_CategoryOption> _categories = [
    _CategoryOption('General', 'eligibility.category_general'),
    _CategoryOption('OBC', 'eligibility.category_obc'),
    _CategoryOption('SC', 'eligibility.category_sc'),
    _CategoryOption('ST', 'eligibility.category_st'),
    _CategoryOption('Women', 'eligibility.category_women'),
    _CategoryOption('Minority', 'eligibility.category_minority'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _annualIncomeController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCategory;
  String? _categoryError;

  @override
  void dispose() {
    _annualIncomeController.dispose();
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

  void _submit() {
    // UI only for now; API wiring (ApiService.fetchMatches) lands later.
    final isFormValid = _formKey.currentState!.validate();
    final isCategoryValid = _selectedCategory != null;

    setState(() {
      _categoryError = isCategoryValid ? null : 'eligibility.category_error'.tr();
    });

    if (isFormValid && isCategoryValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form valid — API wiring pending')),
      );
    }
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                          'eligibility.step_of_label'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'eligibility.header_label'.tr(),
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
                        value: 0.4,
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
                              'eligibility.title'.tr(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'eligibility.subtitle'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _fieldLabel('eligibility.annual_income_label'.tr()),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _annualIncomeController,
                              keyboardType: TextInputType.number,
                              decoration: _fieldDecoration(
                                prefixText: '₹ ',
                                hintText: '0.00',
                              ),
                              validator: (value) {
                                final income = double.tryParse(value ?? '');
                                if (income == null || income < 0) {
                                  return 'eligibility.annual_income_error'
                                      .tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('eligibility.state_label'.tr()),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedState,
                              decoration: _fieldDecoration(),
                              hint: Text('eligibility.state_placeholder'.tr()),
                              items: _states
                                  .map(
                                    (state) => DropdownMenuItem(
                                      value: state,
                                      child: Text(state),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedState = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'eligibility.state_error'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('eligibility.district_label'.tr()),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDistrict,
                              decoration: _fieldDecoration(),
                              hint: Text(
                                'eligibility.district_placeholder'.tr(),
                              ),
                              items: _districts
                                  .map(
                                    (district) => DropdownMenuItem(
                                      value: district,
                                      child: Text(district),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedDistrict = value);
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'eligibility.district_error'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel(
                              'eligibility.estimated_amount_label'.tr(),
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
                                  return 'eligibility.amount_error'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _fieldLabel(
                              'eligibility.social_category_label'.tr(),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((category) {
                                final isSelected =
                                    _selectedCategory == category.value;
                                return ChoiceChip(
                                  label: Text(category.labelKey.tr()),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategory = category.value;
                                      _categoryError = null;
                                    });
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
                                onPressed: _submit,
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
                                    Text('eligibility.find_schemes_button'.tr()),
                                    const SizedBox(width: 8),
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
            const TrustFooter(),
          ],
        ),
      ),
    );
  }
}
