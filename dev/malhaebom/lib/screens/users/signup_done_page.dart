import 'package:malhaebom/screens/users/login_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupDonePage extends StatelessWidget {
  const SignupDonePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Text(
          "회원가입",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  SizedBox(height: screenHeight * 0.2),
                  Icon(
                    Icons.check_circle,
                    color: AppColors.blue,
                    size: screenWidth * 0.35,
                  ),
                  SizedBox(height: 30.h),
                  Text(
                    "정상적으로 회원가입에 성공했습니다!",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "나를 지키는 특별한 습관",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "지금 시작하세요!",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),

              Column(
                children: [
                  CustomSubmitButton(
                    btnText: "로그인",
                    isActive: true,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
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
