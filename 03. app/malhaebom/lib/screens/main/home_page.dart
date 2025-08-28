import 'dart:convert';

import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/screens/main/interview_list_page.dart';
import 'package:malhaebom/screens/main/my_page.dart';
import 'package:malhaebom/screens/story/story_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/home_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:malhaebom/screens/users/login_page.dart'; // ✅ 로그인 페이지 임포트

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _nick; // 로그인한 사용자 닉네임

  @override
  void initState() {
    super.initState();
    _loadNickFromLocal();
  }

  /// 로그인 시 저장한 SharedPreferences의 'auth_user'에서 닉네임을 로드
  Future<void> _loadNickFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('auth_user');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final nick = map['nick'] as String?;
        if (mounted) {
          setState(
            () =>
                _nick =
                    (nick == null || nick.trim().isEmpty) ? null : nick.trim(),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _nick = null);
    }
  }

  /// ✅ 로그아웃: 토큰/유저만 삭제, auto_login은 유지
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // 자동로그인 토큰만 제거
    await prefs.remove('auth_user'); // 표시용 유저 정보 제거
    // ⚠️ prefs.remove('auto_login'); 절대 금지

    if (!mounted) return;
    // 로그인 페이지를 새로 생성해서 pushAndRemoveUntil → 체크박스가 저장값(auto_login)대로 보임
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 공통 여백/크기
    final double gap = 25.h;
    final double logoSize = screenWidth * 0.35;
    final double headerH = logoSize + gap * 2; // 좌/우 헤더 동일 높이

    // 표시할 닉네임 문구
    final String nickText = _nick == null ? '' : '$_nick님,';

    return Scaffold(
      backgroundColor: AppColors.background,

      // ✅ 시스템 상단/하단 영역 피해서 배치
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Row(
              children: [
                // ===== 왼쪽 열 =====
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 15.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 왼쪽 헤더(로고) - 고정 높이
                        SizedBox(
                          height: headerH,
                          child: Center(
                            child: Image.asset(
                              "assets/logo/logo_top.png",
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        SizedBox(height: 25.h),

                        // 첫 번째 카드
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MyPage(),
                              ),
                            );
                          },
                          child: Container(
                            width: screenWidth * 0.4,
                            height: screenHeight * 0.25,
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromARGB(60, 0, 0, 0),
                                  spreadRadius: 5,
                                  blurRadius: 10,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 20.h,
                                horizontal: 20.w,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        "assets/images/fire.png",
                                        height: screenHeight * 0.10,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    "내 정보",
                                    textScaler: const TextScaler.linear(1.0),
                                    style: TextStyle(
                                      fontFamily: 'GmarketSans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 25.h),

                        // 두뇌 단련
                        HomeMenuButton(
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          iconAsset: "assets/icons/light_icon.png",
                          colorIndex: 0,
                          btnName: "두뇌 단련",
                          btnText: "놀이를 통해\n뇌를 단련해요",
                          nextPage: const BrainTrainingMainPage(),
                        ),
                      ],
                    ),
                  ),
                ),

                // ====== 오른쪽 열 ======
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 15.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ✅ 오른쪽 헤더 "카드 스타일"
                        Container(
                          width: screenWidth * 0.4,
                          height: headerH,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nick == null ? "반가워요," : nickText,
                                  textScaler: const TextScaler.linear(1.0),
                                  style: TextStyle(
                                    fontFamily: 'GmarketSans',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20.sp,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  "오늘도 뇌건강\n지키러 가볼까요?",
                                  textScaler: const TextScaler.linear(1.0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15.sp,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: gap),

                        // 인지능력 검사
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const InterviewListPage(),
                              ),
                            );
                          },
                          child: Container(
                            width: screenWidth * 0.4,
                            height: screenHeight * 0.25,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromARGB(60, 0, 0, 0),
                                  spreadRadius: 5,
                                  blurRadius: 10,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_box,
                                    size: screenHeight * 0.10,
                                  ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    "인지 검사",
                                    textScaler: const TextScaler.linear(1.0),
                                    style: TextStyle(
                                      fontFamily: 'GmarketSans',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 25.h),

                        // 회상 동화
                        HomeMenuButton(
                          screenWidth: screenWidth,
                          screenHeight: screenHeight,
                          iconAsset: "assets/icons/book_icon.png",
                          colorIndex: 0,
                          btnName: "회상 동화",
                          btnText: "이야기를 듣고\n활동해요.",
                          nextPage: const StoryMainPage(),
                        ),

                        SizedBox(height: 25.h),
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
