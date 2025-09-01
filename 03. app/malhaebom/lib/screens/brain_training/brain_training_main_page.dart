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
  List<Color> btnColorList = [
    Color(0xFFff0000),
    Color(0xFFf08a2c),
    Color(0xFFe8b100),
    Color(0xFF4bbb06),
    // Color(0xFF344cb7),
    Color(0xFF000957),
    Color(0xFF692498),
    // Color(0xFFff0073),
  ];

  List<String> btnIconList = [
    "assets/icons/spacetime.png",
    "assets/icons/concentration.png",
    "assets/icons/solving.png",
    "assets/icons/calculation.png",
    // "assets/icons/color.png",
    "assets/icons/language.png",
    "assets/icons/music.png",
    // "assets/icons/info.png",
  ];

  List<String> btnTextList = [
    "시공간파악",
    "기억집중",
    "문제해결능력",
    "계산능력",
    // "알록달록",
    "언어능력",
    "음악과터치",
    // "건강정보",
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 세 리스트중 가장 짧은 길이를 기준으로 사용
    final int n = math.min(
      btnTextList.length,
      math.min(btnIconList.length, btnColorList.length),
    );

    // 왼쪽(짝수 인덱스), 오른쪽(홀수 인덱스) 개수
    final int leftCount = (n + 1) ~/ 2; // ceil(n/2)
    final int rightCount = n ~/ 2; // floor(n/2)

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return BackToHome(
      child: Scaffold(
        appBar: AppBar(
          // automaticallyImplyLeading: true,
          centerTitle: true,
          backgroundColor: AppColors.btnColorDark,
          toolbarHeight: _appBarH(context),
          title: Text(
            "두뇌 단련",
            textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
            style: TextStyle(fontFamily: 'GmarketSans', fontWeight: FontWeight.w700, fontSize: 20.sp, color: Colors.white,),
          ),
        ),
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                // 상단 여백
                SizedBox(height: 20.h),

                // 안내 텍스트 - 크기 증가 및 여백 조정
                Text(
                  "오늘은 어떤 역량을 늘려볼까요?\n원하는 활동을 선택해보세요.",
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.4,
                  ),
                ),

                // 텍스트와 버튼 사이 여백 증가
                SizedBox(height: 40.h),

                // 버튼 그리드 - Expanded로 남은 공간 활용
                Expanded(
                  child: Row(
                    children: [
                      // 왼쪽 컬럼 (짝수 인덱스)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 10.w),
                          child: ListView.builder(
                            itemCount: leftCount,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
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
                                      if (btnTextList[index * 2] != "건강정보") {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (
                                                  context,
                                                ) => BrainTrainingStartPage(
                                                  title: btnTextList[index * 2],
                                                ),
                                          ),
                                        );
                                      } else {}
                                    },
                                  ),
                                  SizedBox(height: 25.h),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // 오른쪽 컬럼 (홀수 인덱스)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 10.w),
                          child: ListView.builder(
                            itemCount: rightCount,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
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
                                      if (btnTextList[index * 2 + 1] !=
                                          "건강정보") {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    BrainTrainingStartPage(
                                                      title:
                                                          btnTextList[index *
                                                                  2 +
                                                              1],
                                                    ),
                                          ),
                                        );
                                      } else {}
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

                // 하단 여백
                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
