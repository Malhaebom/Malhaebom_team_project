import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TrainingBtn extends StatelessWidget {
  const TrainingBtn({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.btnIcon,
    required this.btnColor,
    required this.btnText,
    required this.onPressed,
  });

  final double screenWidth;
  final double screenHeight;
  final String btnIcon;
  final Color btnColor;
  final String btnText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: screenWidth * 0.4,
        height: screenHeight * 0.18, // 높이 증가
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(60, 0, 0, 0),
              spreadRadius: 5,
              blurRadius: 10,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(btnIcon, height: screenHeight * 0.055, color: btnColor), // 아이콘 크기 증가
            SizedBox(height: 12.h), // 여백 조정
            Text(
              btnText,
              textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
              style: TextStyle(
                fontFamily: 'GmarketSans',
                color: btnColor,
                fontWeight: FontWeight.w800,
                fontSize: 16.sp, // 텍스트 크기 조정
              ),
            ),
          ],
        ),
      ),
    );
  }
}
