import 'package:flutter/material.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LiquidCircleProgressWidget extends StatelessWidget {
  const LiquidCircleProgressWidget({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100.w,
      height: 100.h,
      child: LiquidCircularProgressIndicator(
        value: value,
        valueColor: AlwaysStoppedAnimation(
          const Color.fromARGB(255, 106, 150, 231),
        ),
        backgroundColor: const Color.fromARGB(255, 43, 63, 151),
        direction: Axis.vertical,
        center: Text(
          "${(value * 100).round()}%",
          style: TextStyle(
            fontFamily: 'GmarketSans',
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: 23.sp,
          ),
        ),
      ),
    );
  }
}
