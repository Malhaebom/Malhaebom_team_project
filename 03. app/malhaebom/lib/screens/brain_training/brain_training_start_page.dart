// brain_training_start_page.dart
import 'package:malhaebom/screens/brain_training/brain_training_test_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTrainingStartPage extends StatefulWidget {
  const BrainTrainingStartPage({super.key, required this.title});

  final String title;

  @override
  State<BrainTrainingStartPage> createState() => _BrainTrainingStartPageState();
}

class _BrainTrainingStartPageState extends State<BrainTrainingStartPage> {
  double _appBarH(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest >= 840) return 88; // 큰 태블릿
    if (shortest >= 600) return 72; // 일반 태블릿
    return kToolbarHeight; // 폰(기본 56)
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ⚠️ WillPopScope 제거: 스택을 자연스럽게 pop 시킵니다. // FIX
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: _appBarH(context),
        title: Text(
          widget.title,
          textScaler: const TextScaler.linear(1.0),
          style: TextStyle(
            fontFamily: 'GmarketSans',
            fontWeight: FontWeight.w700,
            fontSize: 20.sp,
            color: Colors.white,
          ),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  SizedBox(height: screenHeight * 0.2),
                  Image.asset(
                    "assets/images/speaker.png",
                    width: screenWidth * 0.4,
                  ),
                  SizedBox(height: 30.h),
                  Text(
                    "놀이로 하는 뇌 건강 활동!",
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    "정답을 눌러주세요.",
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "문제를 푸는 동안 시간이 측정돼요:)",
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "테스트 중 페이지를 나가면\n기록이 저장되지 않습니다.",
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.red,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  // Start -> Test는 교체로 가볍게 유지 (선택) // FIX (optional)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => BrainTrainingTestPage(title: widget.title),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.btnColorDark,
                      minimumSize: Size(double.infinity, 48.h),
                    ),
                    child: Text(
                      "문제풀기",
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontSize: 18.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
