import 'package:malhaebom/screens/brain_training/brain_training_test_page.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';

class BrainTrainingStartPage extends StatefulWidget {
  const BrainTrainingStartPage({super.key, required this.title});

  final String title;

  @override
  State<BrainTrainingStartPage> createState() => _BrainTrainingStartPageState();
}

class _BrainTrainingStartPageState extends State<BrainTrainingStartPage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 시 BrainTrainingMainPage로 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => BrainTrainingMainPage()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          scrolledUnderElevation: 0,
          centerTitle: true,
          toolbarHeight: _appBarH(context),
          title: Text(
            widget.title,
            textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
            style: TextStyle(fontFamily: 'GmarketSans', fontWeight: FontWeight.w700, fontSize: 20.sp, color: Colors.white),
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
                      textScaler: const TextScaler.linear(
                        1.0,
                      ), // 시스템 폰트 크기 설정 무시
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      "정답을 눌러주세요.",
                      textScaler: const TextScaler.linear(
                        1.0,
                      ), // 시스템 폰트 크기 설정 무시
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      "문제를 푸는 동안 시간이 측정돼요:)",
                      textScaler: const TextScaler.linear(
                        1.0,
                      ), // 시스템 폰트 크기 설정 무시
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      "테스트 중 페이지를 나가면 기록이 저장되지 않습니다.",
                      textScaler: const TextScaler.linear(
                        1.0,
                      ), // 시스템 폰트 크기 설정 무시
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),

                Column(
                  children: [
                    CustomSubmitButton(
                      btnText: "문제풀기",
                      isActive: true,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    BrainTrainingTestPage(title: widget.title),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
