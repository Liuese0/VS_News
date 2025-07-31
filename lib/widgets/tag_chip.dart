import 'package:flutter/material.dart';
import '../utils/constants.dart';

class TagChip extends StatelessWidget {
  final String tag;
  final bool isSelected;
  final VoidCallback onTap;

  const TagChip({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected
                ? AppColors.primaryColor
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}