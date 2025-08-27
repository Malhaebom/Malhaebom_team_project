// lib/screens/main/interview_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';

import 'interview_recording_page.dart';
import '../../data/interview_repo.dart';
import 'interview_session.dart';

class InterviewListPage extends StatefulWidget {
  const InterviewListPage({Key? key}) : super(key: key);

  @override
  State<InterviewListPage> createState() => _InterviewListPageState();
}

class _InterviewListPageState extends State<InterviewListPage> {
  // 색/스타일
  static const _bg = Color(0xFFF6F7FB);
  static const _card = Colors.white;
  static const _divider = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF202124);
  static const _textSub = Color(0xFF6B7280);
  static const _blue = Color(0xFF3B5BFF);

  late final List<_InterviewItem> _items;
  List<bool>? _done; // 진행도 로딩 전 = null (로딩 스피너 노출)

  @override
  void initState() {
    super.initState();

    // 1) 데이터 구성
    final data = InterviewRepo.getAll();
    String summarize(String s, {int max = 18}) {
      final t = s.trim();
      return t.length <= max ? t : t.substring(0, max).trimRight() + '…';
    }

    _items = List.generate(data.length, (i) {
      final d = data[i];
      return _InterviewItem(
        number: d.number,
        title: '${d.number}. ${summarize(d.speechText)}',
        promptText: d.speechText,
      );
    });

    // 2) 진행도 초기화/로드
    _initProgress();
  }

  /// 최초 진입 시 진행도 설정(완료 회차 리셋 + 현재 진행도 로드)
  Future<void> _initProgress() async {
    // 회차가 완전히 끝났다면 초기화
    await InterviewSession.resetIfCompleted(_items.length);
    // 현재 진행도 로드
    final progress = await InterviewSession.getProgress(_items.length);
    if (!mounted) return;
    setState(() {
      _done = progress;
    });
  }

  /// 최신 진행도 재로딩(디스크에서 다시 읽어와 즉시 반영)
  Future<void> _refreshProgress() async {
    final latest = await InterviewSession.getProgress(_items.length);
    if (!mounted) return;
    setState(() => _done = latest);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;

    // ✅ 페이지 전체 글자 크기 고정
    final fixedTextScale = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return MediaQuery(
      data: fixedTextScale,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          elevation: 0.5,
          centerTitle: true,
          // automaticallyImplyLeading: false,
          toolbarHeight: _appBarH(context),
          title: Text(
            '인지 검사',
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
              color: Colors.white,
            ),
          ),
          // actions: [
          //   IconButton(
          //     onPressed: () => Navigator.pop(context),
          //     icon: const Icon(Icons.close),
          //     color: Colors.black87,
          //   ),
          // ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 380.w),
            // 로딩 스피너
            child:
                done == null
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _refreshProgress,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // 상단 안내
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16.w,
                                    16.h,
                                    16.w,
                                    12.h,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '내가 살아온 삶 이야기하기',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'GmarketSans',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13.sp,
                                          color: _textSub.withOpacity(0.95),
                                          height: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        '내가 살아온 삶을\n자유롭게 이야기해보세요.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'GmarketSans',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20.sp,
                                          color: _textDark,
                                          height: 1.28,
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _LegendCircle(
                                            color: _blue,
                                            size: 18.w,
                                            stroke: 3.w,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            '녹음 완료',
                                            style: TextStyle(
                                              fontFamily: 'GmarketSans',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 13.sp,
                                              color: _textDark.withOpacity(0.9),
                                            ),
                                          ),
                                          SizedBox(width: 18.w),
                                          const Icon(
                                            Icons.close_rounded,
                                            size: 20,
                                            color: Colors.black38,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            '녹음 전',
                                            style: TextStyle(
                                              fontFamily: 'GmarketSans',
                                              fontWeight: FontWeight.w400,
                                              fontSize: 13.sp,
                                              color: _textDark.withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(height: 1, color: _divider),

                                // 리스트
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _items.length,
                                  separatorBuilder:
                                      (_, __) =>
                                          Container(height: 1, color: _divider),
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
                                    return _InterviewRow(
                                      done: done[index],
                                      title: item.title,
                                      onTap: () async {
                                        // 회차 완료 전 재녹음 금지
                                        if (done[index]) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '이미 완료한 지문은 회차 종료 전 재녹음할 수 없어요.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final data = InterviewRepo.getByIndex(
                                          index,
                                        );

                                        // 녹음 페이지로 이동
                                        final bool? ok = await Navigator.of(
                                          context,
                                        ).push<bool>(
                                          PageRouteBuilder(
                                            pageBuilder:
                                                (_, __, ___) =>
                                                    InterviewRecordingPage(
                                                      lineNumber: item.number,
                                                      totalLines: _items.length,
                                                      promptText:
                                                          item.promptText,
                                                      assetPath: data?.sound,
                                                    ),
                                            transitionDuration: Duration.zero,
                                            reverseTransitionDuration:
                                                Duration.zero,
                                            transitionsBuilder:
                                                (_, a, __, child) =>
                                                    FadeTransition(
                                                      opacity: a,
                                                      child: child,
                                                    ),
                                          ),
                                        );

                                        if (!mounted) return;

                                        // ✅ 낙관적 반영(UX 빠릿)
                                        if (ok == true) {
                                          setState(() => done[index] = true);
                                        }

                                        // ✅ 디스크 재동기화(실제 저장 반영)
                                        await _refreshProgress();
                                      },
                                    );
                                  },
                                ),
                              ],
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

class _InterviewRow extends StatelessWidget {
  const _InterviewRow({
    required this.done,
    required this.title,
    required this.onTap,
  });

  final bool done;
  final String title;
  final VoidCallback onTap;

  static const _blue = Color(0xFF3B5BFF);
  static const _textDark = Color(0xFF202124);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
          child: Row(
            children: [
              done
                  ? _OutlineCircle(size: 28.w, stroke: 3.w, color: _blue)
                  : const Icon(
                    Icons.close_rounded,
                    size: 28,
                    color: Colors.black26,
                  ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 18.sp,
                    color: _textDark,
                    height: 1.1,
                  ),
                ),
              ),
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black54,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineCircle extends StatelessWidget {
  final double size;
  final double stroke;
  final Color color;
  const _OutlineCircle({
    required this.size,
    required this.stroke,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: stroke),
        ),
      ),
    );
  }
}

class _LegendCircle extends StatelessWidget {
  final double size;
  final double stroke;
  final Color color;
  const _LegendCircle({required this.color, this.size = 16, this.stroke = 2.6});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: stroke),
        ),
      ),
    );
  }
}

class _InterviewItem {
  final int number;
  final String title;
  final String promptText;

  const _InterviewItem({
    required this.number,
    required this.title,
    required this.promptText,
  });
}
