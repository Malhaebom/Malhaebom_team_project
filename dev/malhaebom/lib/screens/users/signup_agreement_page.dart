import 'dart:convert';
import 'package:malhaebom/service/user_service.dart';
import 'package:flutter/services.dart';
import 'package:malhaebom/models/user_model.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:malhaebom/widgets/agreement.dart';
import 'package:malhaebom/screens/users/signup_done_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SignupAgreementPage extends StatefulWidget {
  const SignupAgreementPage({super.key, required this.userModel});

  final UserModel userModel;

  @override
  State<SignupAgreementPage> createState() => _SignupAgreementPageState();
}

class _SignupAgreementPageState extends State<SignupAgreementPage> {
  /* 약관 동의 여부 */
  List<bool?> agreementIsAgree = [false, false, false, false];

  /* 동의 상태 변경 함수 리스트 */
  List<void Function(bool?)> agreementChangeFunctions = [];

  List<dynamic> agreementContent = [];
  Future<void> loadAgreementData() async {
    final data = await rootBundle.loadString(
      'assets/terms_and_conditions.json',
    );
    final decodedData = jsonDecode(data);
    setState(() {
      agreementContent = decodedData;
    });
    agreementChangeFunctions = [
      (bool? value) {
        setState(() {
          // 서비스 이용약관
          agreementIsAgree[0] = value!;
        });
      },
      (bool? value) {
        setState(() {
          // 개인정보 수집 및 이용
          agreementIsAgree[1] = value!;
        });
      },
      (bool? value) {
        setState(() {
          // 민간정보 수집 이용 판매
          agreementIsAgree[2] = value!;
        });
      },
      (bool? value) {
        setState(() {
          // 개인정보 제 3자 제공
          agreementIsAgree[3] = value!;
        });
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    loadAgreementData();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 40.w),
            child: ListView.builder(
              itemCount: agreementContent.length,
              itemBuilder: (context, index) {
                return Agreement(
                  agreementContent: agreementContent[index],
                  isAgree: agreementIsAgree[index]!,
                  onChanged: agreementChangeFunctions[index],
                );
              },
            ),
          ),

          Positioned(
            bottom: 20.h,
            left: 40.w,
            right: 40.w,
            child: Container(
              decoration: BoxDecoration(color: AppColors.white),
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  CustomSubmitButton(
                    btnText: "확인",
                    isActive:
                        agreementIsAgree[0]! &&
                        agreementIsAgree[2]! &&
                        agreementIsAgree[3]!,
                    onPressed: () {
                      /* 회원가입 완료하기 */
                      if (agreementIsAgree[0]! &&
                          agreementIsAgree[2]! &&
                          agreementIsAgree[3]!) {
                        if (UserService.signUp(
                          widget.userModel.copyWith(
                            agreement: {
                              "termsAndConditions": agreementIsAgree[0],
                              "privacyPolicy": agreementIsAgree[1],
                              "sensitiveInfoCollection": agreementIsAgree[2],
                              "thirdPartyInfoSharing": agreementIsAgree[3],
                            },
                          ),
                        )) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignupDonePage(),
                            ),
                          );
                        } else {
                          /* 회원가입 실패 처리 */
                        }
                      }
                    },
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
