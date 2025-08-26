import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';

class CustomSubmitButton extends StatelessWidget {
  const CustomSubmitButton({
    super.key,
    required this.btnText,
    required this.isActive,
    required this.onPressed,
  });

  final String btnText;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? AppColors.accent : AppColors.grey,
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          textStyle: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(
          btnText,
          textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
        ),
      ),
    );
  }
}
