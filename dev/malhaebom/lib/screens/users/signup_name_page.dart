import 'package:malhaebom/models/user_model.dart';
import 'package:malhaebom/screens/users/signup_birth_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:malhaebom/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupNamePage extends StatefulWidget {
  const SignupNamePage({super.key});

  @override
  State<SignupNamePage> createState() => _SignupNamePageState();
}

class _SignupNamePageState extends State<SignupNamePage> {
  final TextEditingController nameController = TextEditingController();
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    nameController.addListener(_checkInput);
  }

  /* 텍스트 필드가 빈칸인지 확인 */
  void _checkInput() {
    setState(() {
      isValid = nameController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    nameController.removeListener(_checkInput);
    nameController.dispose();
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
                    "이름",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  /* 이름 입력란 */
                  CustomTextfield(
                    type: "normal",
                    hintText: "이름을 입력해주세요.",
                    controller: nameController,
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
                        UserModel userModel = UserModel(
                          name: nameController.text,
                        );

                        /* 회원가입 페이지(생일)로 이동 */
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    SignupBirthPage(userModel: userModel),
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
