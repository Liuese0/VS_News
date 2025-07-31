// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      bottom: bottom != null
          ? PreferredSize(
        preferredSize: Size.fromHeight(bottom!.preferredSize.height + 1),
        child: Column(
          children: [
            bottom!,
            Container(
              height: 1,
              color: Colors.grey[200],
            ),
          ],
        ),
      )
          : PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.grey[200],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight +
          (bottom?.preferredSize.height ?? 0) +
          1 // border height
  );
}