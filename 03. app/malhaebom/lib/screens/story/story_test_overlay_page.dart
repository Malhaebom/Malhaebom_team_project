// story_test_overlay_page.dart
//
// 화행 인지검사 : 문제 미리보기/안내 오버레이

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/story/story_test_page.dart';
import 'package:malhaebom/theme/colors.dart';

const _kFont = 'GmarketSans';

// 컬러
const _overlayBg = Color(0xCC2B2B2B);
const _cardBorder = Color(0xFFEFF1F4);
const _chipBg = Color(0xFFF3F5F8);
const _chipBorder = Color(0xFFDCE1E7);
const _chipBadge = Color(0xFFBFC7D2);
const _bodyGray = Color(0xFF6B6F76);
const _ctaYellow = Color(0xFFFACC15);

class StoryTestOverlayPage extends StatefulWidget {
  final String title;
  final String storyImg;
  const StoryTestOverlayPage({
    super.key,
    required this.title,
    required this.storyImg,
  });

  static PageRoute<void> route(final String title, final String storyImg) =>
      PageRouteBuilder(
        opaque: false,
        barrierColor: _overlayBg,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder:
            (_, __, ___) =>
                StoryTestOverlayPage(title: title, storyImg: storyImg),
        transitionsBuilder:
            (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      );

  @override
  State<StoryTestOverlayPage> createState() => _StoryTestOverlayPageState();
}

class _StoryTestOverlayPageState extends State<StoryTestOverlayPage> {
  int _selected = 0; // 1번 기본 선택

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // ===== 중앙 카드 =====
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: 300.w, maxWidth: 320.w),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(color: _cardBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- 파란 헤더 ---
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 18.h),
                        color: AppColors.btnColorDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // "5초 안에" (얇게)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Text(
                                '5초 안에',
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12.sp,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            // 큰 타이틀
                            Text(
                              '맞는 답안 고르기',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 22.sp,
                                height: 1.15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- 본문(흰 배경) ---
                      Padding(
                        padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 18.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 안내 문구 (얇게)
                            Text(
                              '정답을 체크해 주세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontWeight: FontWeight.w400,
                                fontSize: 14.sp,
                                height: 1.25,
                                color: _bodyGray,
                              ),
                            ),
                            SizedBox(height: 14.h),

                            // 상황 지문 (얇게)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '준비물이 필요하면 계란을 팔아서 준비한다.\n'
                                '형제들이 어머니에게 어떻게 말했을까요?',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: _kFont,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12.sp,
                                  height: 1.45,
                                  color: _bodyGray,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // 보기 4개
                            _OptionTile(
                              index: 1,
                              label: '계란 주세요.',
                              selected: _selected == 0,
                              onTap: () => setState(() => _selected = 0),
                            ),
                            SizedBox(height: 8.h),
                            _OptionTile(
                              index: 2,
                              label: '계란 먹고 싶어요.',
                              selected: _selected == 1,
                              onTap: () => setState(() => _selected = 1),
                            ),
                            SizedBox(height: 8.h),
                            _OptionTile(
                              index: 3,
                              label: '준비물 주세요.',
                              selected: _selected == 2,
                              onTap: () => setState(() => _selected = 2),
                            ),
                            SizedBox(height: 8.h),
                            _OptionTile(
                              index: 4,
                              label: '준비물 사주세요.',
                              selected: _selected == 3,
                              onTap: () => setState(() => _selected = 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ===== 상단 우측 '나가기' (워크북 오버레이와 동일 크기) =====
            Positioned(
              top: 10.h,
              right: 14.w,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.85),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(color: Colors.white.withOpacity(0.55)),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '나가기',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 18.sp,
                  ),
                ),
              ),
            ),

            // ===== 하단 노란 CTA =====
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 20.h,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (_) => StoryTestPage(
                            title: widget.title,
                            storyImg: widget.storyImg,
                          ),
                    ),
                  );
                },
                child: Container(
                  height: 64.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ctaYellow,
                    borderRadius: BorderRadius.circular(32.r),
                  ),
                  child: Text(
                    '문제 풀기',
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 20.sp,
                      height: 1.0,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보기 한 줄 위젯
class _OptionTile extends StatelessWidget {
  final int index;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.index,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.btnColorDark : _chipBorder;
    final textColor = selected ? Colors.black : const Color(0xFF33363A);
    final badgeBorder = selected ? AppColors.btnColorDark : _chipBadge;

    return Material(
      color: _chipBg,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          height: 48.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
          ),
          child: Row(
            children: [
              // 번호 배지
              Container(
                width: 22.w,
                height: 22.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5.sp,
                    height: 1.0,
                    color: badgeBorder,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // 보기 텍스트
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontWeight: FontWeight.w500,
                    fontSize: 16.5.sp,
                    height: 1.22,
                    color: textColor,
                  ),
                ),
              ),
              if (selected) ...[
                SizedBox(width: 6.w),
                Icon(
                  Icons.front_hand_rounded,
                  size: 22.sp,
                  color: const Color(0xFF1C1C1C),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
