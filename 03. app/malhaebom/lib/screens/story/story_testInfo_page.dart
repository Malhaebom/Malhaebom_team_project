import 'package:malhaebom/screens/story/story_detail_page.dart';
import 'package:malhaebom/screens/story/story_test_overlay_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _kFont = 'GmarketSans';
const _ctaYellow = Color(0xFFFACC15); // 비디오 페이지와 동일 CTA 색

class StoryTestinfoPage extends StatelessWidget {
  final String title;
  final String storyImg;
  const StoryTestinfoPage({
    super.key,
    required this.title,
    required this.storyImg,
  });

  @override
  Widget build(BuildContext context) {
    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        elevation: 0.5,
        centerTitle: true,
        toolbarHeight: _appBarH(context),
        title: Text(
          '화행 인지검사',
          style: TextStyle(
            fontFamily: 'GmarketSans',
            fontWeight: FontWeight.w700,
            fontSize: 20.sp,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            _infoCard(
              title: '화행 인지검사란?',
              children: [
                Text(
                  '질문에 대한 언어 사용 능력을 평가하여\n응답자의 인지능력을 검사합니다.',
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: 17.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),

            _infoCard(
              title: '검사진행 방법',
              align: CrossAxisAlignment.center, // ✅ 가운데 정렬
              centerTitle: true,
              contentInset: EdgeInsets.zero, // ✅ 왼쪽 인셋 제거
              children: [
                _stepTitle(
                  icon: Icons.question_answer_outlined,
                  text: '문제 제시',
                ), // ✅ alignStart 제거(=가운데)
                Text(
                  '동화 내용에 기반한 문제를\n제시하는 음성이 나와요.',
                  textAlign: TextAlign.center, // ✅ 가운데
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: 17.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                SizedBox(height: 14.h),

                _stepTitle(icon: Icons.check_circle_outline, text: '답안 선택'),
                Text(
                  '올바른 답안을 선택한 후,\n다음 버튼을 눌러\n다음 문제로 넘어가세요.',
                  textAlign: TextAlign.center, // ✅ 가운데
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: 17.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),

            _infoCard(
              title: '동화를 모두 읽으셨나요?',
              children: [
                Text(
                  '동화기반의 문제가 출제됩니다.\n동화를 꼭 보고 검사를 시작해주세요.',
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
                    fontSize: 17.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                SizedBox(height: 18.h),

                // ===== 버튼 영역: 비디오 페이지와 동일 모양 =====
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceButton(
                        top: '네',
                        bottom: '검사할게요.',
                        background: _ctaYellow,
                        foreground: Colors.black,
                        onTap: () => _goToOverlay(context),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _ChoiceButton(
                        top: '아니요',
                        bottom: '다 안 봤어요.',
                        background: const Color(0xFFE9E9EB),
                        foreground: const Color(0xFF5B5B5B),
                        onTap: () => _goBackToDetail(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== 네비게이션 헬퍼 =====

  void _goToOverlay(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) =>
                StoryTestOverlayPage(title: title, storyImg: storyImg),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _goBackToDetail(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StoryDetailPage(title: title, storyImg: storyImg),
      ),
    );
  }

  // ===== UI 유틸 =====

  Widget _infoCard({
    required String title,
    required List<Widget> children,
    CrossAxisAlignment align = CrossAxisAlignment.center,
    bool centerTitle = true,
    EdgeInsetsGeometry contentInset = EdgeInsets.zero,
  }) {
    final titleText = Text(
      title,
      textScaler: const TextScaler.linear(1.0),
      style: TextStyle(fontSize: 23.5.sp, fontWeight: FontWeight.w900),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (centerTitle)
            Center(child: titleText)
          else
            Align(alignment: Alignment.centerLeft, child: titleText),
          SizedBox(height: 10.h),
          Padding(
            padding: contentInset,
            child: Column(crossAxisAlignment: align, children: children),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle({
    required IconData icon,
    required String text,
    bool alignStart = false,
  }) {
    final double iconBox = 28.w;
    final double gap = 8.w;

    final iconBubble = Container(
      width: iconBox,
      height: iconBox,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF3F4F6),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22.sp, color: const Color(0xFF111827)),
    );

    if (alignStart) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h, top: 10.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            iconBubble,
            SizedBox(width: gap),
            Text(
              text,
              textAlign: TextAlign.start,
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(fontSize: 21.5.sp, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 10.h),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconBubble,
            SizedBox(width: gap),
            Text(
              text,
              textAlign: TextAlign.center,
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(fontSize: 21.5.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: iconBox + gap), // 👈 균형용 더미 공간
          ],
        ),
      ),
    );
  }
}

// ====== 버튼 컴포넌트 ======
class _ChoiceButton extends StatelessWidget {
  final String top;
  final String bottom;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.top,
    required this.bottom,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fixedScale = TextScaler.linear(1.0); // 버튼 내부 글씨 스케일 고정

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 64.h,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                top,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: fixedScale,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 20.sp,
                  color: foreground,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                bottom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: fixedScale,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                  color: foreground.withOpacity(.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
