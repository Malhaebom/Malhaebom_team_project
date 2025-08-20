import 'package:brain_up/models/user_model.dart';
import 'package:brain_up/screens/users/signup_agreement_page.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:brain_up/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupGenderPage extends StatefulWidget {
  const SignupGenderPage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupGenderPage> createState() => _SignupGenderPageState();
}

class _SignupGenderPageState extends State<SignupGenderPage> {
  bool? isFemale = false;
  bool? isMale = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(
          "회원가입",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "성별",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  Row(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isFemale,
                            onChanged: (value) {
                              setState(() {
                                if (isMale!) {
                                  isMale = false;
                                }
                                isFemale = value;
                              });
                            },
                            activeColor: AppColors.blue,
                            checkColor: Colors.white,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            "여성",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 20.sp,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 40.w),
                      Row(
                        children: [
                          Checkbox(
                            value: isMale,
                            onChanged: (value) {
                              setState(() {
                                if (isFemale!) {
                                  isFemale = false;
                                }
                                isMale = value;
                              });
                            },
                            activeColor: AppColors.blue,
                            checkColor: Colors.white,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            "남성",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 20.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  /* 제출 버튼 */
                  CustomSubmitButton(
                    btnText: "확인",
                    isActive: isFemale! || isMale!,
                    onPressed: () {
                      if (isFemale! || isMale!) {
                        String gender = isFemale! ? "FEMALE" : "MALE";

                        /* 개인정보 수집 동의 페이지로 이동*/
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SignupAgreementPage(
                                  userModel: widget.userModel.copyWith(
                                    gender: gender,
                                  ),
                                ),
                          ),
                        );
                      }
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
