import 'package:brain_up/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AutobiographyPage extends StatefulWidget {
  const AutobiographyPage({super.key});

  @override
  State<AutobiographyPage> createState() => _AutobiographyPageState();
}

class _AutobiographyPageState extends State<AutobiographyPage> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: screenHeight * 0.4,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset("assets/images/book.png", fit: BoxFit.contain),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60.h),
                      child: Column(
                        children: [
                          Text(
                            "레벤님의 자서전",
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              fontWeight: FontWeight.w600,
                              fontSize: 20.sp,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 30.h),
                          Image.asset(
                            "assets/images/default_img.png",
                            height: screenHeight * 0.15,
                          ),
                          SizedBox(height: 45.h),
                          Text(
                            "2025.04.09",
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
            AutobiographyBtn(
              btnText: "다른 자서전 보기",
              isBlue: true,
              onPressed: () {},
            ),
            SizedBox(height: 10.h),
            AutobiographyBtn(
              btnText: "자서전 작성하기",
              isBlue: false,
              onPressed: () {},
            ),
            SizedBox(height: 10.h),
            AutobiographyBtn(
              btnText: "나의 자서전 보기",
              isBlue: false,
              onPressed: () {},
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class AutobiographyBtn extends StatelessWidget {
  const AutobiographyBtn({
    super.key,
    required this.btnText,
    required this.isBlue,
    required this.onPressed,
  });

  final String btnText;
  final bool isBlue;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isBlue ? AppColors.blue : AppColors.white,
          foregroundColor: isBlue ? AppColors.white : AppColors.text,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(btnText),
      ),
    );
  }
}
