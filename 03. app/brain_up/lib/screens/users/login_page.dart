import 'package:brain_up/screens/main/main_page.dart';
import 'package:brain_up/screens/users/signup_name_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:brain_up/widgets/custom_textfield.dart';
import 'package:brain_up/widgets/custom_submit_button.dart';
import 'package:brain_up/view_models/user_view_model.dart';
import 'package:brain_up/widgets/custom_alert_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late TextEditingController idController;
  late TextEditingController passwordController;

  final UserViewModel userViewModel = UserViewModel();

  @override
  void initState() {
    super.initState();
    idController = TextEditingController();
    passwordController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  SizedBox(
                    width: screenWidth * 0.6,
                    child: Image.asset("assets/logo/logo_long.png"),
                  ),
                  SizedBox(height: 35.h),

                  /* 아이디 입력 필드 */
                  CustomTextfield(
                    controller: idController,
                    type: "id",
                    hintText: "전화번호를 입력하세요.",
                  ),

                  SizedBox(height: 10.h),

                  /* 비밀번호 입력 필드 */
                  CustomTextfield(
                    controller: passwordController,
                    type: "password",
                    hintText: "비밀번호를 입력하세요.",
                  ),

                  SizedBox(height: 40.h),

                  /* 로그인 버튼 */
                  CustomSubmitButton(
                    onPressed: () {
                      String loginCode = userViewModel.login(
                        idController.text,
                        passwordController.text,
                      );
                      switch (loginCode) {
                        case "NULL_ERROR":
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '로그인 실패',
                                  content: '입력하지 않은 값이 있습니다.',
                                ),
                          );
                          break;

                        case "NUMBERIC_ERROR":
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '로그인 실패',
                                  content: '전화번호는 번호로만 입력해주세요.',
                                ),
                          );
                          break;

                        case "ID_ERROR":
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '로그인 실패',
                                  content: '전화번호를 다시 한 번 확인해주세요.',
                                ),
                          );
                          break;

                        case "PASSWORD_ERROR":
                          showDialog(
                            context: context,
                            builder:
                                (_) => CustomAlertDialog(
                                  title: '로그인 실패',
                                  content: '비밀번호를 다시 한 번 확인해주세요.',
                                ),
                          );
                          break;

                        case "LOGIN_SUCCESS":
                          // 메인 화면으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MainPage()),
                          );
                          break;
                      }
                    },
                    btnText: "로그인",
                    isActive: true,
                  ),

                  SizedBox(height: 10),

                  /* 회원가입 버튼 */
                  CustomSubmitButton(
                    onPressed: () {
                      // 회원가입 페이지로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SignupNamePage(),
                        ),
                      );
                    },
                    btnText: "회원가입",
                    isActive: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
