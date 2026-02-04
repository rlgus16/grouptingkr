import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class OwnerBadge extends StatelessWidget {
  final double size;
  final double? iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final Color borderColor;
  final double borderWidth;
  final String? gender;

  const OwnerBadge({
    super.key,
    this.size = 20,
    this.iconSize,
    this.backgroundColor = AppTheme.primaryColor,
    this.iconColor = Colors.white,
    this.borderColor = Colors.white,
    this.borderWidth = 2.0,
    this.gender,
  });

  @override
  Widget build(BuildContext context) {
    // 성별이 '여'이면 secondaryColor, 아니면 기본 backgroundColor(primaryColor) 사용
    final Color badgeColor = (gender == '여') 
        ? AppTheme.secondaryColor 
        : backgroundColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.star,
        size: iconSize ?? (size * 0.5),
        color: iconColor,
      ),
    );
  }
}
