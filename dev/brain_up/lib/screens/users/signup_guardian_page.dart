import 'package:brain_up/models/user_model.dart';
import 'package:brain_up/screens/users/signup_instructor_page.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:brain_up/widgets/custom_alert_dialog.dart';
import 'package:brain_up/widgets/custom_submit_button.dart';
import 'package:brain_up/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupGuardianPage extends StatefulWidget {
  const SignupGuardianPage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupGuardianPage> createState() => _SignupGuardianPageState();
}

class _SignupGuardianPageState extends State<SignupGuardianPage> {
  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController guardianPhoneController = TextEditingController();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    guardianNameController.addListener(_checkInput);
    guardianPhoneController.addListener(_checkInput);
  }

  /* 텍스트 필드가 빈칸인지 확인 */
  void _checkInput() {
    setState(() {
      isValid =
          guardianNameController.text.isNotEmpty &&
          guardianPhoneController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    guardianNameController.removeListener(_checkInput);
    guardianPhoneController.removeListener(_checkInput);
    guardianNameController.dispose();
    guardianPhoneController.dispose();
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
                  Text(
                    "보호자 이름",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 보호자 이름 입력란 */
                  CustomTextfield(
                    type: "normal",
                    hintText: "보호자 이름을 입력해주세요.",
                    controller: guardianNameController,
                  ),

                  SizedBox(height: 20.h),

                  Text(
                    "보호자 전화번호",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 보호자 전화번호 입력란 */
                  CustomTextfield(
                    type: "phone",
                    hintText: "보호자 전화번호를 입력해주세요.",
                    controller: guardianPhoneController,
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
                      final isNumeric = RegExp(
                        r'^\d+$',
                      ).hasMatch(guardianPhoneController.text);

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
                        /* 회원가입 페이지(담당강사 정보)로 이동 */
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SignupInstructorPage(
                                  userModel: widget.userModel.copyWith(
                                    guardianInfo: {
                                      "guardianName":
                                          guardianNameController.text,
                                      "guardianPhoneNumber":
                                          guardianPhoneController.text,
                                    },
                                  ),
                                ),
                          ),
                        );
                      }
                    },
                  ),

                  SizedBox(height: 10.h),

                  CustomSubmitButton(
                    btnText: "건너뛰기",
                    isActive: false,
                    onPressed: () {
                      /* 회원가입 페이지(담당강사 정보)로 이동 */
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => SignupInstructorPage(
                                userModel: widget.userModel,
                              ),
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
