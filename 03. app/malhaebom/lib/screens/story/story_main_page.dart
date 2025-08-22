import 'package:malhaebom/screens/story/story_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/widgets/back_to_home.dart';
import 'package:malhaebom/data/fairytale_assets.dart';

class StoryMainPage extends StatefulWidget {
  const StoryMainPage({super.key});

  @override
  State<StoryMainPage> createState() => _StoryMainPageState();
}

class _StoryMainPageState extends State<StoryMainPage> {

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final tales = Fairytales;
    return BackToHome(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          centerTitle: true,
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
              children: List.generate(tales.length, (index) {
                final tale = tales[index];
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => StoryDetailPage(
                                  title: tale.title,
                                  storyImg: tale.titleImg,
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
                                tale.titleImg,
                                height: screenHeight * 0.07,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tale.title,
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(
                                        fontFamily: 'GmarketSans',
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      tale.content ?? '소개 문구가 준비 중입니다.',
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
      ),
    );
  }
}
