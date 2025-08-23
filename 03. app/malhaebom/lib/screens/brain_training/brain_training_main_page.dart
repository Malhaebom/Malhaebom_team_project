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

    return BackToHome(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          centerTitle: true,
          backgroundColor: AppColors.background,
          title: Text(
            "두뇌 단련",
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
          ),
        ),
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Column(
              children: [
                Text(
                  "오늘은 어떤 역량을 늘려볼까요?\n원하는 활동을 선택해보세요.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: 20.h),

                Row(
                  children: [
                    // 왼쪽 컬럼 (짝수 인덱스)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 15.w),
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
                                              (context) =>
                                                  BrainTrainingStartPage(
                                                    title:
                                                        btnTextList[index * 2],
                                                  ),
                                        ),
                                      );
                                    } else {
                                    }
                                  },
                                ),
                                SizedBox(height: 20.h),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // 오른쪽 컬럼 (홀수 인덱스)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 15.w),
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
                                    if (btnTextList[index * 2 + 1] != "건강정보") {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  BrainTrainingStartPage(
                                                    title:
                                                        btnTextList[index * 2 +
                                                            1],
                                                  ),
                                        ),
                                      );
                                    } else {
                                    }
                                  },
                                ),
                                SizedBox(height: 20.h),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
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
