// brain_training_main_page.dart
import 'dart:math' as math;
import 'package:malhaebom/screens/brain_training/brain_training_start_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/back_to_home.dart';
import 'package:malhaebom/widgets/brain_training_btn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTrainingMainPage extends StatefulWidget {
  const BrainTrainingMainPage({super.key});

  @override
  State<BrainTrainingMainPage> createState() => _BrainTrainingMainPageState();
}

class _BrainTrainingMainPageState extends State<BrainTrainingMainPage> {
  List<Color> btnColorList = const [
    Color(0xFFff0000),
    Color(0xFFf08a2c),
    Color(0xFFe8b100),
    Color(0xFF4bbb06),
    Color(0xFF000957),
    Color(0xFF692498),
  ];

  List<String> btnIconList = const [
    "assets/icons/spacetime.png",
    "assets/icons/concentration.png",
    "assets/icons/solving.png",
    "assets/icons/calculation.png",
    "assets/icons/language.png",
    "assets/icons/music.png",
  ];

  List<String> btnTextList = const [
    "시공간파악",
    "기억집중",
    "문제해결능력",
    "계산능력",
    "언어능력",
    "음악과터치",
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final int n = math.min(
      btnTextList.length,
      math.min(btnIconList.length, btnColorList.length),
    );

    final int leftCount = (n + 1) ~/ 2;
    final int rightCount = n ~/ 2;

    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return BackToHome(
      child: Scaffold(
        appBar: AppBar(
          // automaticallyImplyLeading: true, // 기본값: 스택에 이전 페이지가 있으면 자동 표시
          // ↓ 항상 상단 뒤로가기를 강제로 보이고 싶다면 주석 해제 (선택)
          // leading: const BackButton(color: Colors.white), // FIX (optional)
          centerTitle: true,
          backgroundColor: AppColors.btnColorDark,
          toolbarHeight: _appBarH(context),
          title: Text(
            "두뇌 단련",
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
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),
                Text(
                  "오늘은 어떤 역량을 늘려볼까요?\n원하는 활동을 선택해보세요.",
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 40.h),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 10.w),
                          child: ListView.builder(
                            itemCount: leftCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Column(
                                children: [
                                  TrainingBtn(
                                    screenHeight: screenHeight,
                                    screenWidth: screenWidth,
                                    btnColor: btnColorList[index * 2],
                                    btnIcon: btnIconList[index * 2],
                                    btnText: btnTextList[index * 2],
                                    onPressed: () {
                                      final title = btnTextList[index * 2];
                                      if (title != "건강정보") {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => BrainTrainingStartPage(
                                                  title: title,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  SizedBox(height: 25.h),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 10.w),
                          child: ListView.builder(
                            itemCount: rightCount,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Column(
                                children: [
                                  TrainingBtn(
                                    screenHeight: screenHeight,
                                    screenWidth: screenWidth,
                                    btnColor: btnColorList[index * 2 + 1],
                                    btnIcon: btnIconList[index * 2 + 1],
                                    btnText: btnTextList[index * 2 + 1],
                                    onPressed: () {
                                      final title = btnTextList[index * 2 + 1];
                                      if (title != "건강정보") {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => BrainTrainingStartPage(
                                                  title: title,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  SizedBox(height: 25.h),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
