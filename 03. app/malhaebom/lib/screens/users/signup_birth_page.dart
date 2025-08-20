import 'package:malhaebom/models/user_model.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_alert_dialog.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/widgets/custom_textfield.dart';
import 'package:malhaebom/screens/users/signup_phone_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupBirthPage extends StatefulWidget {
  const SignupBirthPage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupBirthPage> createState() => _SignupBirthPageState();
}

class _SignupBirthPageState extends State<SignupBirthPage> {
  final TextEditingController birthController = TextEditingController();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    birthController.addListener(_checkInput);
  }

  /* 텍스트 필드가 빈칸인지 확인 */
  void _checkInput() {
    setState(() {
      isValid = birthController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    birthController.removeListener(_checkInput);
    birthController.dispose();
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
                      "생일",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),

                  SizedBox(height: 10),

                  /* 생일 입력란 */
                  CustomTextfield(
                    type: "birth",
                    hintText: "생일을 8자로 입력해주세요. 예) 20181123",
                    controller: birthController,
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
                        ).hasMatch(birthController.text);

                        if (!isNumeric || birthController.text.length != 8) {
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '생일 입력 오류',
                                  content: '생일은 숫자 8자로 작성해주세요.',
                                ),
                          );
                        } else {
                          /* 회원가입 페이지(전화번호)로 이동 */
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SignupPhonePage(
                                    userModel: widget.userModel.copyWith(
                                      birthDate: birthController.text,
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
