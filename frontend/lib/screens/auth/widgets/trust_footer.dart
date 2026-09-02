import 'package:flutter/material.dart';

class TrustFooter extends StatelessWidget {
  const TrustFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade600,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      color: const Color(0xFFD9E3F4),
      child: Column(
        children: [
          Text(
            '© Government Financial Services',
            style: mutedStyle.copyWith(color: Colors.grey.shade800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Privacy Policy', style: mutedStyle),
              Text('Terms of Service', style: mutedStyle),
              Text('Help Center', style: mutedStyle),
            ],
          ),
        ],
      ),
    );
  }
}
