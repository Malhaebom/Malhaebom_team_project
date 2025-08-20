import 'package:malhaebom/models/user_model.dart';
import 'package:malhaebom/screens/users/signup_gender_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:malhaebom/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupInstructorPage extends StatefulWidget {
  const SignupInstructorPage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupInstructorPage> createState() => _SignupInstructorPageState();
}

class _SignupInstructorPageState extends State<SignupInstructorPage> {
  final TextEditingController instructorNumController = TextEditingController();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    instructorNumController.addListener(_checkInput);
  }

  /* 텍스트 필드가 빈칸인지 확인 */
  void _checkInput() {
    setState(() {
      isValid = instructorNumController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    instructorNumController.removeListener(_checkInput);
    instructorNumController.dispose();
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
                    "담당강사 고유번호",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 담당강사 고유번호 입력란 */
                  CustomTextfield(
                    type: "normal",
                    hintText: "담당강사 고유번호를 입력해주세요.",
                    controller: instructorNumController,
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
                        /* 회원가입 페이지(성별)로 이동 */
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SignupGenderPage(
                                  userModel: widget.userModel.copyWith(
                                    instructorId: instructorNumController.text,
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
                      /* 회원가입 페이지(성별)로 이동 */
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  SignupGenderPage(userModel: widget.userModel),
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
