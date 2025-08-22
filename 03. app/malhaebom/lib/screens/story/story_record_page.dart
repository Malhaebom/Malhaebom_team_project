// lib/screens/story/story_record_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'story_recording_page.dart';
import '../../data/fairytale_repo.dart';

class StoryRecordPage extends StatefulWidget {
  final String title; // AppBar: "{제목} 연극"
  final int? totalLines; // 옵션: 지정 시 강제 (단, 실제 리스트가 비어있을 때만 사용)
  final List<String>? lines; // 옵션: 지정 시 우선 (텍스트만)

  const StoryRecordPage({
    Key? key,
    required this.title,
    this.totalLines,
    this.lines,
  }) : super(key: key);

  @override
  State<StoryRecordPage> createState() => _StoryRecordPageState();
}

class _StoryRecordPageState extends State<StoryRecordPage> {
  // 스타일
  static const _bg = Color(0xFFF6F7FB);
  static const _card = Colors.white;
  static const _divider = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF202124);
  static const _textSub = Color(0xFF6B7280);
  static const _blue = Color(0xFF3B5BFF);

  late final List<RoleLine> _items; // 텍스트+오디오
  late final int _count;
  late List<bool> recorded;

  @override
  void initState() {
    super.initState();

    // 👇 여기만 변경: temp에 모두 계산 후 마지막에 한 번만 _items에 대입
    List<RoleLine> temp;

    // 1) 외부에서 lines가 오면 텍스트만으로 구성 (최우선)
    if (widget.lines != null && widget.lines!.isNotEmpty) {
      temp = widget.lines!
          .map((t) => RoleLine(text: t, sound: null))
          .toList(growable: false);
    } else {
      // 2) repo에서 rolePlay 자동 추출(텍스트+사운드)
      temp = FairytaleRepo.getRolePlayItems(widget.title);
    }

    // 3) 둘 다 비었을 때만 totalLines(혹은 1)로 placeholder 생성
    if (temp.isEmpty) {
      final fallbackCount = widget.totalLines ?? 1;
      temp = List<RoleLine>.generate(
        fallbackCount,
        (i) => RoleLine(text: '${i + 1}번 대사의 스크립트가 여기에 표시됩니다.'),
      );

      // 👇 디버깅 보조: 실제 항목이 비어서 placeholder가 생성되었음을 알림
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('원본 대사 목록을 찾지 못해 자리표시로 표시합니다. (제목/데이터/경로 확인)'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }

    _items = temp; // ✅ 단 한 번만 초기화
    _count = _items.length;
    recorded = List<bool>.filled(_count, false);
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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 380.w),
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
                    // 안내 영역
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
                              fontWeight: FontWeight.w500,
                              fontSize: 13.sp,
                              color: _textSub.withOpacity(0.95),
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            '1번부터 $_count번까지\n차례대로 따라해보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              fontWeight: FontWeight.w500,
                              fontSize: 20.sp,
                              color: _textDark,
                              height: 1.28,
                            ),
                          ),
                          SizedBox(height: 12.h),
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

                    // 대사 리스트
                    ...List.generate(_count * 2 - 1, (i) {
                      if (i.isOdd) {
                        return Container(height: 1, color: _divider);
                      }
                      final idx = i ~/ 2;
                      return _LineRow(
                        number: idx + 1,
                        done: recorded[idx],
                        onTap: () async {
                          final item = _items[idx];
                          final bool? ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => StoryRecordingPage(
                                    title: widget.title,
                                    lineNumber: idx + 1,
                                    totalLines: _count, // 진행바 최대값은 실제 개수
                                    lineText: item.text,
                                    lineAssetPath: item.sound, // 원본 오디오 경로(있으면)
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
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
          child: Row(
            children: [
              done
                  ? _OutlineCircle(size: 36.w, stroke: 4.w, color: _blue)
                  : const Icon(
                    Icons.close_rounded,
                    size: 36,
                    color: Colors.black26,
                  ),
              SizedBox(width: 16.w),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '$number번 대사',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 24.sp,
                      color: _textDark,
                      height: 1.06,
                    ),
                  ),
                ),
              ),
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
