import 'package:brain_up/models/user_model.dart';
import 'package:brain_up/screens/users/signup_guardian_page.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:brain_up/widgets/custom_alert_dialog.dart';
import 'package:brain_up/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:brain_up/widgets/custom_textfield.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupPasswordPage extends StatefulWidget {
  const SignupPasswordPage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupPasswordPage> createState() => _SignupPasswordPageState();
}

class _SignupPasswordPageState extends State<SignupPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController rePasswordController = TextEditingController();

  bool isValid = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_checkInput);
    rePasswordController.addListener(_checkInput);
  }

  /* 텍스트 필드가 빈칸인지 확인 */
  void _checkInput() {
    setState(() {
      isValid =
          passwordController.text.isNotEmpty &&
          rePasswordController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    passwordController.removeListener(_checkInput);
    rePasswordController.removeListener(_checkInput);
    passwordController.dispose();
    rePasswordController.dispose();
    super.dispose();
  }

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
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      "비밀번호",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 비밀번호 입력란 */
                  CustomTextfield(
                    type: "password_signup",
                    hintText: "비밀번호를 입력해주세요.",
                    controller: passwordController,
                  ),

                  SizedBox(height: 20.h),

                  Text(
                    "비밀번호 재입력",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 비밀번호 !재!입력란 */
                  CustomTextfield(
                    type: "password_signup",
                    hintText: "비밀번호를 재입력해주세요.",
                    controller: rePasswordController,
                  ),
                ],
              ),
              Column(
                children: [
                  /* 제출 버튼 */
                  CustomSubmitButton(
                    btnText: "확인",
                    isActive: isValid,
                    onPressed: () {
                      if (isValid) {
                        /* 회원가입 페이지(보호자 정보)로 이동 */
                        if (passwordController.text !=
                            rePasswordController.text) {
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '비밀번호 입력 오류',
                                  content: '비밀번호가 일치하지 않습니다.',
                                ),
                          );
                        } else {
                          /* 회원가입 페이지(보호자 정보)로 이동 */
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SignupGuardianPage(
                                    userModel: widget.userModel.copyWith(
                                      password: passwordController.text,
                                    ),
                                  ),
                            ),
                          );
                        }
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
