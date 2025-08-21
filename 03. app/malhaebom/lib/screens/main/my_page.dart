import 'package:flutter/material.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/widgets/back_to_home.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final List<String> title = ["회원정보 수정하기", "로그아웃", "자주 묻는 질문"];
  final List<Icon> icon = [
    Icon(Icons.edit, color: AppColors.text, size: 20),
    Icon(Icons.logout, color: AppColors.text, size: 20),
    Icon(Icons.question_answer, color: AppColors.text, size: 20),
  ];

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    return BackToHome(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          // 뒤로가기 버튼 자동 표시
          automaticallyImplyLeading: true,
          title: const Text("설정"),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
            child: Column(
              children: [
                // 섹션 1: 설정
                Material(
                  // 👉 InkWell 위에 Material 제공
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        SizedBox(height: 5.h),
                        Row(
                          children: [
                            SizedBox(width: 10.w),
                            Text(
                              "설정",
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: List.generate(title.length, (index) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(0),
                              onTap: () {
                                // TODO: 각 항목 액션
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey,
                                      width: 1.w,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(width: 10.w),
                                        icon[index],
                                        SizedBox(width: 5.w),
                                        Text(
                                          title[index],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16.sp,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.navigate_next,
                                      size: 40.h,
                                      color: AppColors.text,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 15.h),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // 섹션 2: 문의하기
                Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        SizedBox(height: 5.h),
                        Row(
                          children: [
                            SizedBox(width: 10.w),
                            Text(
                              "문의하기",
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),

                        InkWell(
                          onTap: () {
                            copyText("lebengrida@naver.com");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("클립보드에 복사되었습니다")),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey,
                                  width: 1.w,
                                ),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(width: 10.w),
                                    Icon(
                                      Icons.mail_rounded,
                                      color: AppColors.text,
                                      size: 20.h,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      "이메일",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16.sp,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "lebengrida@naver.com",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14.sp,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.copy,
                                      color: AppColors.text,
                                      size: 20.h,
                                    ),
                                    SizedBox(width: 10.w),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            copyText("051-923-2205");
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("클립보드에 복사되었습니다")),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey,
                                  width: 1.w,
                                ),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(width: 10.w),
                                    Icon(
                                      Icons.phone_enabled,
                                      color: AppColors.text,
                                      size: 20.h,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      "전화",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16.sp,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "051-923-2205",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14.sp,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.copy,
                                      color: AppColors.text,
                                      size: 20.h,
                                    ),
                                    SizedBox(width: 10.w),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 15.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
