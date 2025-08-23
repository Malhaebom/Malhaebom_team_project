import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/screens/main/interview_list_page.dart';
import 'package:malhaebom/screens/main/my_page.dart';
import 'package:malhaebom/screens/story/story_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/home_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SizedBox(width: 10),
            Text(
              "말해봄",
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.blue, // 원하는 색상
                // fontFamily: 'YourCustomFont', // 커스텀 폰트를 사용하는 경우
              ),
            ),
            // Image.asset(
            //   "assets/logo/logo_brainup.png",
            //   height: kToolbarHeight * 0.5,
            // ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 15.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /* 
                        프로필 정보
                    */
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MyPage()),
                          );
                        },
                        child: Container(
                          width: screenWidth * 0.4,
                          height: screenHeight * 0.25,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
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
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 20.h,
                              horizontal: 20.w,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "레벤님,",
                                      textScaler: const TextScaler.linear(1.0),
                                      style: TextStyle(
                                        fontFamily: 'GmarketSans',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20.sp,
                                      ),
                                    ),
                                    Text(
                                      "오늘도 뇌건강\n지키러 가볼까요?",
                                      textScaler: const TextScaler.linear(1.0),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15.sp,
                                      ),
                                      textAlign: TextAlign.start,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Image.asset(
                                          "assets/images/fire.png",
                                          height: screenHeight * 0.07,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 25.h),

                      /* 
                        두뇌 단련
                    */
                      HomeMenuButton(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        iconAsset: "assets/icons/light_icon.png",
                        colorIndex: 0,
                        btnName: "두뇌 단련",
                        btnText: "놀이를 통해\n뇌를 단련해요",
                        nextPage: BrainTrainingMainPage(),
                      ),

                      SizedBox(height: 25.h),

                      Image.asset(
                        "assets/logo/logo_top.png",
                        width: screenWidth * 0.35,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: 15.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      /* 
                      화상 훈련
                    */
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InterviewListPage(),
                                ),
                              );
                            },
                            child: Container(
                              width: screenWidth * 0.4,
                              height: screenHeight * 0.25,
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
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_box,
                                      size: screenHeight * 0.10,
                                    ),
                                    SizedBox(height: 10.h),
                                    Text(
                                      "회상 훈련",
                                      textScaler: const TextScaler.linear(1.0),
                                      style: TextStyle(
                                        fontFamily: 'GmarketSans',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 25.h),
                      /* 
                        회상 동화
                    */
                      HomeMenuButton(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        iconAsset: "assets/icons/book_icon.png",
                        colorIndex: 0,
                        btnName: "회상 동화",
                        btnText: "이야기를 듣고\n활동해요.",
                        nextPage: StoryMainPage(),
                      ),

                      SizedBox(height: 25.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
