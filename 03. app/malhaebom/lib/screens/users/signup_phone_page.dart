import 'package:malhaebom/models/user_model.dart';
import 'package:malhaebom/screens/users/signup_password_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_alert_dialog.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/widgets/custom_textfield.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupPhonePage extends StatefulWidget {
  const SignupPhonePage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupPhonePage> createState() => _SignupPhonePageState();
}

class _SignupPhonePageState extends State<SignupPhonePage> {
  final TextEditingController phoneController = TextEditingController();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    phoneController.addListener(_checkInput);
  }

  /* 텍스트 필드가 빈칸인지 확인 */
  void _checkInput() {
    setState(() {
      isValid = phoneController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    phoneController.removeListener(_checkInput);
    phoneController.dispose();
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
                      "전화번호",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 생일 입력란 */
                  CustomTextfield(
                    type: "birth",
                    hintText: "전화번호를 숫자로만 입력해주세요.",
                    controller: phoneController,
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
                        /* 회원가입 페이지(생일)로 이동 */
                        final isNumeric = RegExp(
                          r'^\d+$',
                        ).hasMatch(phoneController.text);

                        if (!isNumeric) {
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '전화번호 입력 오류',
                                  content: '전화번호는 문자 없이 숫자로만 입력해주세요.',
                                ),
                          );
                        } else {
                          /* 회원가입 페이지(보호자 정보)로 이동 */
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SignupPasswordPage(
                                    userModel: widget.userModel.copyWith(
                                      phoneNumber: phoneController.text,
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
