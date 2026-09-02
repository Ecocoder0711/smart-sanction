import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/india_locations.dart';
import '../auth/widgets/trust_footer.dart';
import 'location_screen.dart';

class _ChipOption {
  const _ChipOption(this.value, this.labelKey);

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

  static const List<_ChipOption> _categories = [
    _ChipOption('General', 'eligibility.category_general'),
    _ChipOption('OBC', 'eligibility.category_obc'),
    _ChipOption('SC', 'eligibility.category_sc'),
    _ChipOption('ST', 'eligibility.category_st'),
  ];

  static const List<_ChipOption> _genders = [
    _ChipOption('Male', 'eligibility.gender_male'),
    _ChipOption('Female', 'eligibility.gender_female'),
    _ChipOption('Other', 'eligibility.gender_other'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _annualIncomeController = TextEditingController();

  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCategory;
  String? _categoryError;
  String? _selectedGender;
  String? _genderError;

  @override
  void dispose() {
    _annualIncomeController.dispose();
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
    // UI/navigation only — not connected to the backend yet.
    final isFormValid = _formKey.currentState!.validate();
    final isCategoryValid = _selectedCategory != null;
    final isGenderValid = _selectedGender != null;

    setState(() {
      _categoryError = isCategoryValid
          ? null
          : 'eligibility.category_error'.tr();
      _genderError = isGenderValid ? null : 'eligibility.gender_error'.tr();
    });

    if (isFormValid && isCategoryValid && isGenderValid) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LocationScreen()),
      );
    }
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _chipGroup({
    required List<_ChipOption> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedValue == option.value;
        return ChoiceChip(
          label: Text(option.labelKey.tr()),
          selected: isSelected,
          onSelected: (_) => onSelected(option.value),
          backgroundColor: AppColors.softGray,
          selectedColor: AppColors.deepNavy.withValues(alpha: 0.1),
          side: BorderSide(
            color: isSelected ? AppColors.deepNavy : _borderColor,
          ),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.deepNavy : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final districtOptions = _selectedState == null
        ? const <String>[]
        : IndiaLocations.stateDistricts[_selectedState] ?? const <String>[];

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
                        value: 0.5,
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
                            _fieldLabel(
                              'eligibility.annual_income_label'.tr(),
                            ),
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
                              isExpanded: true,
                              decoration: _fieldDecoration(),
                              hint: Text(
                                'eligibility.state_placeholder'.tr(),
                                overflow: TextOverflow.ellipsis,
                              ),
                              items: IndiaLocations.states
                                  .map(
                                    (state) => DropdownMenuItem(
                                      value: state,
                                      child: Text(
                                        state,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedState = value;
                                  _selectedDistrict = null;
                                });
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
                              isExpanded: true,
                              decoration: _fieldDecoration(),
                              hint: Text(
                                _selectedState == null
                                    ? 'eligibility.district_select_state_first'
                                          .tr()
                                    : 'eligibility.district_placeholder'.tr(),
                                overflow: TextOverflow.ellipsis,
                              ),
                              items: districtOptions
                                  .map(
                                    (district) => DropdownMenuItem(
                                      value: district,
                                      child: Text(
                                        district,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _selectedState == null
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _selectedDistrict = value,
                                      );
                                    },
                              validator: (value) {
                                if (value == null) {
                                  return 'eligibility.district_error'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _fieldLabel(
                              'eligibility.social_category_label'.tr(),
                            ),
                            const SizedBox(height: 8),
                            _chipGroup(
                              options: _categories,
                              selectedValue: _selectedCategory,
                              onSelected: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  _categoryError = null;
                                });
                              },
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
                            const SizedBox(height: 20),
                            _fieldLabel('eligibility.gender_label'.tr()),
                            const SizedBox(height: 8),
                            _chipGroup(
                              options: _genders,
                              selectedValue: _selectedGender,
                              onSelected: (value) {
                                setState(() {
                                  _selectedGender = value;
                                  _genderError = null;
                                });
                              },
                            ),
                            if (_genderError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _genderError!,
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
                                child: Text('eligibility.continue_button'.tr()),
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
