import 'package:malhaebom/screens/story/story_detail_page.dart';
import 'package:malhaebom/screens/story/story_test_overlay_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const String _kFont = 'GmarketSans';

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          '화행 인지검사',
          style: TextStyle(
            fontFamily: _kFont,
            fontWeight: FontWeight.w400, // ← 굵지 않게
            fontSize: 20.sp,
            color: Colors.black,
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
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400, // ← 얇게
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),

            _infoCard(
              title: '검사진행 방법',
              align: CrossAxisAlignment.start,
              centerTitle: true,
              contentInset: EdgeInsets.only(left: 60.w),
              children: [
                _stepTitle(
                  icon: Icons.question_answer_outlined,
                  text: '문제 제시',
                  alignStart: true,
                ),
                Text(
                  '동화 내용에 기반한 문제를\n제시하는 음성이 나와요.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400, // ← 얇게
                    color: const Color(0xFF4B5563),
                  ),
                ),
                SizedBox(height: 14.h),

                _stepTitle(
                  icon: Icons.timer_outlined,
                  text: '시간 제한',
                  alignStart: true,
                ),
                // 5초 언급 제거
                Text(
                  '음성이 모두 나온 후\n답을 체크할 수 있어요.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400, // ← 얇게
                    color: const Color(0xFF4B5563),
                  ),
                ),
                SizedBox(height: 14.h),

                _stepTitle(
                  icon: Icons.check_circle_outline,
                  text: '답안 선택',
                  alignStart: true,
                ),
                // 5초 언급 제거
                Text(
                  '올바른 답안을 선택하세요.\n선택하지 못하면 \n추가 기회가 제공돼요.',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400, // ← 얇게
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
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w400, // ← 얇게
                    color: const Color(0xFF4B5563),
                  ),
                ),
                SizedBox(height: 18.h),

                Row(
                  children: [
                    // 네: overlay 페이지로 이동
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE066),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: () => _goToOverlay(context),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '네',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              '검사할게요.',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400, // ← 얇게
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // 아니요: 뒤로(=디테일 페이지로 복귀)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          backgroundColor: const Color(0xFFE9E9EB),
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _goBackToDetail(context),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '아니요',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              '다 안 봤어요.',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400, // ← 얇게
                              ),
                            ),
                          ],
                        ),
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
      style: TextStyle(
        fontFamily: _kFont,
        fontSize: 20.5.sp, // ← 제목 더 큼
        fontWeight: FontWeight.w900,
      ),
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
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 10.h),
      child: Row(
        mainAxisAlignment:
            alignStart ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF3F4F6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17.sp, color: Color(0xFF111827)),
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            textAlign: alignStart ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              fontFamily: _kFont,
              fontSize: 18.5.sp, // ← 단계 제목 더 큼
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
