import 'package:flutter/material.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LiquidCircleProgressWidget extends StatelessWidget {
  const LiquidCircleProgressWidget({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    // 파일이 실행되는지 확인
    print('=== LiquidCircleProgressWidget 실행됨 ===');
    print('LiquidCircleProgressWidget - Original value: $value');
    print('LiquidCircleProgressWidget - value * 100: ${value * 100}');
    print('LiquidCircleProgressWidget - toStringAsFixed(0): ${(value * 100).toStringAsFixed(0)}');
    
    // 강제로 정수 변환
    final percentage = (value * 100).toInt();
    print('LiquidCircleProgressWidget - toInt(): $percentage');
    print('=== 디버깅 완료 ===');
    
    return SizedBox(
      width: 100.w,
      height: 100.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 바깥쪽 테두리 원 (동심원)
          Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color.fromARGB(255, 106, 150, 231),
                width: 8,
              ),
            ),
          ),
          // 안쪽 물이 출렁거리는 원 (크기 조정)
          SizedBox(
            width: 84.w,  // 100 - 16 (테두리 두께)
            height: 84.h,
            child: LiquidCircularProgressIndicator(
              value: value,
              valueColor: AlwaysStoppedAnimation(
                const Color.fromARGB(255, 106, 150, 231),
              ),
              backgroundColor: const Color.fromARGB(255, 43, 63, 151),
              direction: Axis.vertical,
            ),
          ),
          Text(
            "$percentage%",
            style: TextStyle(
              fontFamily: 'GmarketSans',
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 23.sp,
            ),
          ),
        ],
      ),
    );
  }
}
