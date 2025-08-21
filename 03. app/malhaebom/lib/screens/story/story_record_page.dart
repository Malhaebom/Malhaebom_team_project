import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'story_recording_page.dart'; // 녹음 화면

/// 동화 연극하기 → 녹음 목록 페이지 (안내+리스트 하나의 카드로 구성)
class StoryRecordPage extends StatefulWidget {
  final String title; // AppBar: "{제목} 연극"
  final int totalLines; // 총 대사 수 (기본 38)
  final List<String>? lines; // 대사 스크립트 (옵션)

  const StoryRecordPage({
    Key? key,
    required this.title,
    this.totalLines = 38,
    this.lines,
  }) : super(key: key);

  @override
  State<StoryRecordPage> createState() => _StoryRecordPageState();
}

class _StoryRecordPageState extends State<StoryRecordPage> {
  // 상태
  late List<bool> recorded;

  // 스타일 상수
  static const _bg = Color(0xFFF6F7FB);
  static const _card = Colors.white;
  static const _divider = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF202124);
  static const _textSub = Color(0xFF6B7280);
  static const _blue = Color(0xFF3B5BFF);

  late final List<String> _lines;

  @override
  void initState() {
    super.initState();
    recorded = List<bool>.filled(widget.totalLines, false); // 전부 미녹음

    _lines = List<String>.generate(widget.totalLines, (i) {
      if (i == 0) return '어머니 : 얘들아, 아버지 회사 나가신다. 인사해야지.'; // 샘플
      return '${i + 1}번 대사의 스크립트가 여기에 표시됩니다.';
    });
    if (widget.lines != null && widget.lines!.isNotEmpty) {
      for (int i = 0; i < widget.lines!.length && i < _lines.length; i++) {
        _lines[i] = widget.lines![i];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          leadingWidth: 0,
          automaticallyImplyLeading: false,
          title: Text(
            '${widget.title} 연극',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w500,
              fontSize: 18.sp,
              color: Colors.black,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              color: Colors.black87,
            ),
          ],
        ),
      ),

      // 가운데 정렬 + 최대폭 제한
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 380.w),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            children: [
              // === 안내 + 리스트가 하나의 카드 ===
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
                    // ----- 안내 영역 -----
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '이야기 주인공의 대사 따라하기',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              fontWeight: FontWeight.w500, // 굵지 않게
                              fontSize: 13.sp,
                              color: _textSub.withOpacity(0.95),
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            '1번부터 ${widget.totalLines}번까지\n차례대로 따라해보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              fontWeight: FontWeight.w500, // 굵지 않게
                              fontSize: 20.sp, // 약간 크게
                              color: _textDark,
                              height: 1.28,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          // 범례
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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

                    // ----- 대사 리스트 (카드 내부에 연속) -----
                    ...List.generate(widget.totalLines * 2 - 1, (i) {
                      if (i.isOdd) {
                        // 아이템 사이 구분선
                        return Container(height: 1, color: _divider);
                      }
                      final idx = i ~/ 2;
                      return _LineRow(
                        number: idx + 1,
                        done: recorded[idx],
                        onTap: () async {
                          final bool? ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => StoryRecordingPage(
                                    title: widget.title,
                                    lineNumber: idx + 1,
                                    totalLines: widget.totalLines,
                                    lineText: _lines[idx],
                                  ),
                            ),
                          );
                          if (ok == true) {
                            setState(() => recorded[idx] = true);
                          }
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 리스트 한 줄 — 가운데 정렬, 더 큰 도형/글씨, ▶ 아이콘
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.number,
    required this.done,
    required this.onTap,
  });

  final int number;
  final bool done;
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
          // 전체적으로 더 큼직
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
          child: Row(
            children: [
              // 상태 아이콘: 완료(파란 원) / 미완료(X) — 더 큼
              done
                  ? _OutlineCircle(size: 36.w, stroke: 4.w, color: _blue)
                  : const Icon(
                    Icons.close_rounded,
                    size: 36,
                    color: Colors.black26,
                  ),
              SizedBox(width: 16.w),

              // "n번 대사" — 더 크게(24sp), 굵게(리스트만)
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '$number번 대사',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 24.sp, // ↑ 키움
                      color: _textDark,
                      height: 1.06,
                    ),
                  ),
                ),
              ),

              // 우측 ▶ 아이콘 — 조금 키움
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black54,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 파란 외곽 원
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

/// 범례용 원
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
