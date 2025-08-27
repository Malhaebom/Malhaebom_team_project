import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplashPage extends StatefulWidget {
  final Widget next;
  const SplashPage({super.key, required this.next});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  // 만약 native_splash에 로고 이미지를 넣었다면 true 로 바꾸면 됨 (문구만 서서히 등장)
  static const bool logoFromNative = true;

  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _ac,
    curve: logoFromNative
        ? const Interval(0.0, 0.0)             // 이미 보이는 로고 = 애니메이션 없음
        : const Interval(0.0, 0.55, curve: Curves.easeOut),
  );

  late final Animation<double> _logoScale = Tween<double>(
    begin: logoFromNative ? 1.0 : 0.98,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _ac,
    curve: logoFromNative ? const Interval(0.0, 0.0) : const Interval(0.0, 0.55, curve: Curves.easeOutBack),
  ));

  late final Animation<double> _titleOpacity = CurvedAnimation(
    parent: _ac,
    curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _ac.forward();      // 애니메이션 시작
    _goNext();          // 애니메이션 도는 동안 다음 화면 준비
  }

  Future<void> _goNext() async {
    // 애니메이션 + 최소 노출 보장 (원하면 1800~2200ms 사이로 조절)
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tagline = '말로 피어나는 추억의 꽃,\n <말해봄과 함께>하세요.'; // <> 안만 굵게

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 시안과 같은 상하 그라데이션
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F3FB), Color(0xFFF7FBFE)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // 로고 (로고 네이티브 미사용 시: 살짝 확대되며 페이드인)
                FadeTransition(
                  opacity: logoFromNative ? const AlwaysStoppedAnimation(1.0) : _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/logo/logo_top.png',
                      width: 120.w,
                      height: 120.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                // 큰 타이틀
                // FadeTransition(
                //   opacity: _titleOpacity,
                //   child: Text(
                //     '말해봄',
                //     textAlign: TextAlign.center,
                //     style: TextStyle(
                //       fontFamily: 'Pretendard',
                //       fontWeight: FontWeight.w800,
                //       fontSize: 42.sp,
                //       height: 1.1,
                //       color: const Color(0xFF264B5E),
                //     ),
                //   ),
                // ),
                // SizedBox(height: 24.h),
                // 태그라인 (<> 두툼)
                FadeTransition(
                  opacity: _titleOpacity,
                  child: _AngleBoldText(
                    text: tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.sp,
                      height: 1.6,
                      color: const Color(0xFF4B5563),
                    ),
                    boldStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14.sp,
                      height: 1.6,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// "<...>" 안만 굵게
class _AngleBoldText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? boldStyle;
  final TextAlign? textAlign;
  const _AngleBoldText({required this.text, this.style, this.boldStyle, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final reg = RegExp(r'<([^>]+)>');
    int i = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start), style: style));
      spans.add(TextSpan(text: m.group(1)!, style: boldStyle ?? style));
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i), style: style));
    return Text.rich(TextSpan(children: spans), textAlign: textAlign);
  }
}
