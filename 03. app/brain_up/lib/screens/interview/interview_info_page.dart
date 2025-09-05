// lib/screens/main/interview_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:brain_up/theme/colors.dart';

import 'interview_recording_page.dart';
import '../../data/interview_repo.dart';
import 'interview_session.dart';

const _kFont = 'GmarketSans';
const _ctaYellow = Color(0xFFFACC15); // CTA 색상(동화 안내 페이지와 톤 맞춤)

class InterviewInfoPage extends StatefulWidget {
  const InterviewInfoPage({Key? key}) : super(key: key);

  @override
  State<InterviewInfoPage> createState() => _InterviewIntroPageState();
}

class _InterviewIntroPageState extends State<InterviewInfoPage> {
  bool _starting = false; // 시작 버튼 로딩 표시용

  // 상단바 높이
  double _appBarH(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    if (shortest >= 840) return 88;
    if (shortest >= 600) return 72;
    return kToolbarHeight;
  }

  Future<void> _startInterview() async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      // 인터뷰 데이터
      final items = InterviewRepo.getAll();
      final total = items.length;

      // 회차가 모두 끝났으면 새 회차로 초기화
      await InterviewSession.resetIfCompleted(total);

      // 현재 진행도에서 "미완료" 첫 인덱스 찾기
      final progress = await InterviewSession.getProgress(total);
      int idx = 0; // 기본 0번(=1번 문항)
      for (int i = 0; i < total; i++) {
        if (i >= progress.length || progress[i] == false) {
          idx = i;
          break;
        }
        if (i == total - 1) idx = 0; // 모두 true였던 케이스 방어
      }

      final d = InterviewRepo.getByIndex(idx);
      if (!mounted || d == null) return;

      // 첫(또는 다음) 문항으로 이동
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => InterviewRecordingPage(
                lineNumber: d.number,
                totalLines: total,
                promptText: d.speechText,
                assetPath: d.sound,
              ),
          transitionsBuilder:
              (_, a, __, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixedScale = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1));

    return MediaQuery(
      data: fixedScale,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          elevation: 0.5,
          centerTitle: true,
          toolbarHeight: _appBarH(context),
          title: Text(
            '인지 검사',
            style: TextStyle(
              fontFamily: _kFont,
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
                title: '인지 검사는 무엇을 하나요?',
                children: [
                  Text(
                    '질문을 듣고 말로 대답하는 과정을 통해\n언어 사용과 회상 능력 등을 평가해요.',
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
                title: '검사 진행 방법',
                centerTitle: true,
                align: CrossAxisAlignment.center, // ✅ 가운데 정렬
                contentInset: EdgeInsets.zero, // ✅ 인셋 제거
                children: [
                  _stepTitle(
                    icon: Icons.volume_up_outlined,
                    text: '질문 듣기',
                  ), // ✅ 가운데
                  Text(
                    '각 문항마다 안내 음성이\n먼저 재생돼요.',
                    textAlign: TextAlign.center, // ✅ 가운데
                    textScaler: const TextScaler.linear(1.0),
                    style: _body(),
                  ),
                  SizedBox(height: 12.h),

                  _stepTitle(icon: Icons.mic_none_rounded, text: '답변 녹음'),
                  Text(
                    '녹음 버튼을 눌러\n자유롭게 말해주세요.\n최대 30초까지 녹음됩니다.',
                    textAlign: TextAlign.center, // ✅ 가운데
                    textScaler: const TextScaler.linear(1.0),
                    style: _body(),
                  ),
                  SizedBox(height: 12.h),

                  _stepTitle(
                    icon: Icons.check_circle_outline,
                    text: '저장 후 다음 문항',
                  ),
                  Text(
                    '‘녹음 끝내기’를 누르면 저장되고\n다음 문항으로 넘어갈 수 있어요.',
                    textAlign: TextAlign.center, // ✅ 가운데
                    textScaler: const TextScaler.linear(1.0),
                    style: _body(),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              _infoCard(
                title: '원활한 진행을 위해',
                align: CrossAxisAlignment.center,
                children: [
                  _centerLine('조용한 환경에서 진행해주세요.'),
                  _centerLine('마이크 권한을 허용해주세요.'),
                  _centerLine('이번 회차 중 이미 완료한 문항은\n재녹음이 제한돼요.'),
                ],
              ),
              SizedBox(height: 22.h),

              // ===== CTA 영역 (동화 안내 페이지와 유사 레이아웃) =====
              Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      top: _starting ? '준비중...' : '네',
                      bottom: '검사 시작할게요.',
                      background: _ctaYellow,
                      foreground: Colors.black,
                      onTap: _starting ? null : _startInterview,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _ChoiceButton(
                      top: '아니요',
                      bottom: '나중에 할래요.',
                      background: const Color(0xFFE9E9EB),
                      foreground: const Color(0xFF5B5B5B),
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 텍스트 스타일 유틸 =====
  TextStyle _body() => TextStyle(
    fontSize: 17.5.sp,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF4B5563),
    height: 1.4,
  );

  // ===== 공통 UI =====
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
      style: TextStyle(
        fontFamily: _kFont,
        fontSize: 23.5.sp,
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

  Widget _centerLine(String s) => Padding(
    padding: EdgeInsets.only(top: 6.h),
    child: Text(
      s,
      textAlign: TextAlign.center,
      textScaler: const TextScaler.linear(1.0),
      style: _body(),
    ),
  );

  Widget _stepTitle({
    required IconData icon,
    required String text,
    bool alignStart = false,
  }) {
    final double iconBox = 28.w; // 아이콘 원 크기
    final double gap = 8.w; // 아이콘-텍스트 간격

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
      // 기존: 왼쪽 정렬(가이드 등에서 필요하면 사용)
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h, top: 8.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            iconBubble,
            SizedBox(width: gap),
            Text(
              text,
              textAlign: TextAlign.start,
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 21.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    // ✅ 가운데 정렬: 텍스트 기준으로 중앙이 정확히 맞도록
    // 오른쪽에 아이콘과 동일한 폭(gap 포함)의 더미 SizedBox를 추가
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 8.h),
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
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 21.5.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: iconBox + gap), // 👈 균형용 더미 공간
          ],
        ),
      ),
    );
  }
}

// ===== 버튼 컴포넌트 =====
class _ChoiceButton extends StatelessWidget {
  final String top;
  final String bottom;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _ChoiceButton({
    required this.top,
    required this.bottom,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const fixedScale = TextScaler.linear(1.0);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: AnimatedSize(
          // 폰트 로딩 후 크기 변화도 부드럽게
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 64.h), // ← 최소 높이만 보장
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    top,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    textScaler: fixedScale,
                    // 폰트가 아직 안 떠도 동일한 행높이를 강제
                    strutStyle: StrutStyle(
                      forceStrutHeight: true,
                      height: 1.1,
                      fontFamily: _kFont,
                      fontSize: 20.sp,
                    ),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontWeight: FontWeight.w800, // 가능하면 w700 사용 권장
                      fontSize: 20.sp,
                      color: foreground,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    bottom,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    textScaler: fixedScale,
                    strutStyle: StrutStyle(
                      forceStrutHeight: true,
                      height: 1.1,
                      fontFamily: _kFont,
                      fontSize: 13.sp,
                    ),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
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
        ),
      ),
    );
  }
}
