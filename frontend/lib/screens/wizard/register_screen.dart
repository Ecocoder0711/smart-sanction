import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'eligibility_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _backgroundColor = Color(0xFFF9FAFB);
  static const Color _borderColor = Color(0xFFD1D5DB);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EligibilityScreen()),
      );
    }
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppColors.softGray,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          size: 40,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'auth.register_header'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: _inputDecoration(
                        'auth.full_name_label'.tr(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'auth.full_name_error'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        'auth.phone_number_label'.tr(),
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                          return 'auth.phone_error'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _inputDecoration('auth.password_label'.tr()),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'auth.password_error'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('auth.register_button'.tr()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text('auth.have_account_login'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
