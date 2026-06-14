import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../theme/responsive.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const AppBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Back',
      button: true,
      child: GestureDetector(
        onTap: onPressed ?? () => Get.back(),
        child: Container(
          width: context.r.scale(44),
          height: context.r.scale(44),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(60),
            borderRadius: BorderRadius.circular(context.r.scale(14)),
            border: Border.all(color: Colors.white.withAlpha(80), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: context.r.scale(18),
            color: color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}
