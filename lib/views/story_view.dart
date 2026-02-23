import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StoryView extends StatelessWidget {
  const StoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Text(
          'Stories Coming Soon!',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
