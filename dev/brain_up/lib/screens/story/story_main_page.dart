import 'package:brain_up/screens/story/story_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StoryMainPage extends StatefulWidget {
  const StoryMainPage({super.key});

  @override
  State<StoryMainPage> createState() => _StoryMainPageState();
}

class _StoryMainPageState extends State<StoryMainPage> {
  List<String> storyImg = [
    "assets/fairytale/어머니의벙어리장갑_img.png",
    "assets/fairytale/아버지와결혼식_img.png",
  ];

  List<Map<String, String>> storyContent = [
    {"title": "어머니의 벙어리장갑", "content": "1960년도 추운 겨울,\n3남매 가족의 사랑을 그리는 이야기에요."},
    {
      "title": "아버지와 결혼식",
      "content": "1980년대, 부산에 사는 딸과 아버지의\n가슴이 뭉클해지는 이야기에요.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          "회상 동화",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
          child: Column(
            children: List.generate(storyImg.length, (index) {
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => StoryDetailPage(
                                title: storyContent[index]["title"]!,
                              ),
                        ),
                      );
                    },
                    child: Container(
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
                        padding: EdgeInsets.symmetric(
                          vertical: 15.h,
                          horizontal: 10.w,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              storyImg[index],
                              height: screenHeight * 0.07,
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storyContent[index]["title"]!,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      fontFamily: 'GmarketSans',
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    storyContent[index]["content"]!,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
