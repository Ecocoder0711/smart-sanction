import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'intake_details_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  static const Color _surface = Color(0xFFF8F9FF);
  static const Color _surfaceContainerHighest = Color(0xFFD9E3F4);
  static const Color _surfaceContainer = Color(0xFFE5EEFF);
  static const Color _borderColor = Color(0xFFD1D5DB);
  static const Color _voiceAssistantBg = Color(0xFF003320);
  static const Color _voiceAssistantFg = Color(0xFF00A774);

  void _selectLanguage(BuildContext context, String language) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const IntakeDetailsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(color: _borderColor),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          size: 40,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please select your preferred language to continue '
                        'with your financial assistance application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 48),
                      _LanguageButton(
                        label: 'English',
                        isPrimary: true,
                        onTap: () => _selectLanguage(context, 'en'),
                      ),
                      const SizedBox(height: 16),
                      _LanguageButton(
                        label: 'हिंदी',
                        isPrimary: false,
                        onTap: () => _selectLanguage(context, 'hi'),
                      ),
                      const SizedBox(height: 16),
                      _LanguageButton(
                        label: 'मराठी',
                        isPrimary: false,
                        onTap: () => _selectLanguage(context, 'mr'),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.deepNavy,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You can change this later in settings.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () {},
                backgroundColor: _voiceAssistantBg,
                foregroundColor: _voiceAssistantFg,
                icon: const Icon(Icons.mic),
                label: const Text(
                  'Voice Assistant',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isPrimary
              ? AppColors.deepNavy
              : Colors.white,
          foregroundColor: isPrimary ? Colors.white : AppColors.deepNavy,
          side: BorderSide(
            color: isPrimary
                ? AppColors.deepNavy
                : LanguageSelectionScreen._borderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}
