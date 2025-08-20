import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTrainingInfoPage extends StatelessWidget {
  const BrainTrainingInfoPage({super.key});

  static Map<String, dynamic> data = {
    "건강정보01": {
      "title": "몸짱을 만들어주는 건강 식품",
      "image": "assets/training/brain/info/01.png",
    },
    "건강정보02": {
      "title": "건강한 식단을 위한 비법",
      "image": "assets/training/brain/info/02.png",
    },
    "건강정보03": {
      "title": "동맥경화와 치매의 상관관계",
      "image": "assets/training/brain/info/03.png",
    },
    "건강정보04": {
      "title": "뇌 건강을 위한 채소 섭취 방법",
      "image": "assets/training/brain/info/04.png",
    },
    "건강정보05": {
      "title": "초기 치매 대처 방법",
      "image": "assets/training/brain/info/05.png",
    },
    "건강정보06": {
      "title": "심장 튼튼한 노인, 치매 위험 낮다",
      "image": "assets/training/brain/info/06.png",
    },
    "건강정보07": {
      "title": "인지 활동과 운동의 중요성",
      "image": "assets/training/brain/info/07.png",
    },
    "건강정보08": {
      "title": "치매 예방에 도움이 되는 생활습관",
      "image": "assets/training/brain/info/08.png",
    },
    "건강정보09": {
      "title": "건강장수 12가지 수칙",
      "image": "assets/training/brain/info/09.png",
    },
    "건강정보10": {"title": "치매상담센터", "image": "assets/training/brain/info/10.png"},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          "건강정보",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
          child: Column(
            children: List.generate(data.length, (index) {
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => BrainTrainingInfoDetailPage(
                                title: data.keys.toList()[index],
                                image:
                                    data[data.keys.toList()[index]]["image"]!,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.keys.toList()[index],
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontFamily: 'GmarketSans',
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  data[data.keys.toList()[index]]["title"]!,
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(fontSize: 12.sp),
                                ),
                              ],
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

class BrainTrainingInfoDetailPage extends StatelessWidget {
  const BrainTrainingInfoDetailPage({
    super.key,
    required this.title,
    required this.image,
  });

  final String title;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        child: Expanded(child: Image.asset(image)),
      ),
    );
  }
}
