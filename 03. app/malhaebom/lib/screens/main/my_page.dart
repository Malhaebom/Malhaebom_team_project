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
  final List<Icon> icon = const [
    Icon(Icons.edit, color: AppColors.text, size: 26),
    Icon(Icons.logout, color: AppColors.text, size: 26),
    Icon(Icons.question_answer, color: AppColors.text, size: 26),
  ];

  void copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 이 화면에서만 글자 확대/축소 고정 (시스템 텍스트 스케일 무시)
    final fixedMedia = MediaQuery.of(context).copyWith(
      textScaler: const TextScaler.linear(1.0),
      // Flutter 3.13 이하라면: textScaleFactor: 1.0 를 사용
    );

    return BackToHome(
      child: MediaQuery(
        data: fixedMedia,
        child: Scaffold(
          backgroundColor: AppColors.background,

          // ✅ AppBar는 일단 숨김
          appBar: null,
          // 필요해지면 아래 블록 주석 해제하고 위의 appBar: null을 지우면 됩니다.
          /*
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            automaticallyImplyLeading: true,
            title: const Text("설정"),
          ),
          */

          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
              child: Column(
                children: [
                  // 섹션 1: 설정
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
                                "설정",
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 26.sp,
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
                                      Expanded( // ← 왼쪽 영역을 가변폭으로
                                        child: Row(
                                          children: [
                                            SizedBox(width: 10.w),
                                            icon[index],
                                            SizedBox(width: 5.w),
                                            Flexible(
                                              child: Text(
                                                title[index],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 22.sp,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),

                          // 이메일
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
                                  // ← 왼쪽을 Expanded로 감싸 폭 초과 시 텍스트는 말줄임
                                  Expanded(
                                    child: Row(
                                      children: [
                                        SizedBox(width: 10.w),
                                        Icon(
                                          Icons.mail_rounded,
                                          color: AppColors.text,
                                          size: 26.h,
                                        ),
                                        SizedBox(width: 5.w),
                                        Text(
                                          "이메일",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 22.sp,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Flexible(
                                          child: Text(
                                            "lebengrida@naver.com",
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 20.sp,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
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

                          // 전화
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
                                  Expanded(
                                    child: Row(
                                      children: [
                                        SizedBox(width: 10.w),
                                        Icon(
                                          Icons.phone_enabled,
                                          color: AppColors.text,
                                          size: 26.h,
                                        ),
                                        SizedBox(width: 5.w),
                                        Text(
                                          "전화",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 22.sp,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Flexible(
                                          child: Text(
                                            "051-923-2205",
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 20.sp,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
