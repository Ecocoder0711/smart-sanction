import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(child: Text('dashboard.list_pending'.tr())),
    );
  }
}
