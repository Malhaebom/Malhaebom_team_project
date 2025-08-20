import 'package:malhaebom/screens/brain_training/brain_training_test_page.dart';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
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
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    "정답을 눌러주세요.",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "문제를 푸는 동안 시간이 측정돼요:)",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "테스트 중 페이지를 나가면 기록이 저장되지 않습니다.",
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
    );
  }
}
