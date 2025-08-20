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
        height: screenHeight * 0.15,
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
            Image.asset(btnIcon, height: screenHeight * 0.045, color: btnColor),
            SizedBox(height: 10.h),
            Text(
              btnText,
              style: TextStyle(
                fontFamily: 'GmarketSans',
                color: btnColor,
                fontWeight: FontWeight.w800,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
