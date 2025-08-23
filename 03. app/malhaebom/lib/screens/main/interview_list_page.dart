import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'interview_recording_page.dart';
// 인터뷰 데이터 리포지토리 (프로젝트 경로에 맞게 조정하세요)
import '../../data/interview_repo.dart';

class InterviewListPage extends StatefulWidget {
  const InterviewListPage({Key? key}) : super(key: key);

  @override
  State<InterviewListPage> createState() => _InterviewListPageState();
}

class _InterviewListPageState extends State<InterviewListPage> {
  static const _bg = Color(0xFFF6F7FB);
  static const _card = Colors.white;
  static const _divider = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF202124);
  static const _textSub = Color(0xFF6B7280);
  static const _blue = Color(0xFF3B5BFF);

  late final List<_InterviewItem> _items;
  late List<bool> _done;

  @override
  void initState() {
    super.initState();

    // repo에서 모든 항목 로드(텍스트 기반으로 목록 생성)
    final data = InterviewRepo.getAll();

    String summarize(String s, {int max = 18}) {
      final t = s.trim();
      return t.length <= max ? t : t.substring(0, max).trimRight() + '…';
    }

    _items = List.generate(data.length, (i) {
      final d = data[i];
      return _InterviewItem(
        number: d.number,
        title: '${d.number}. ${summarize(d.speechText)}', // 목록 타이틀(큰 글씨 한 줄만)
        promptText: d.speechText, // 녹음 페이지에 넘길 전체 지문
      );
    });

    _done = List<bool>.filled(_items.length, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          '회상 훈련',
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
                    // 상단 안내/전설
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
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

                    // 리스트(세퍼레이터 사용) — 큰 글씨 한 줄만 노출
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder:
                          (_, __) => Container(height: 1, color: _divider),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _InterviewRow(
                          done: _done[index],
                          title: item.title,
                          onTap: () async {
                            // 녹음 화면으로 이동 시에만 mp3 경로 조회
                            final data = InterviewRepo.getByIndex(index);
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => InterviewRecordingPage(
                                      lineNumber: item.number,
                                      totalLines: _items.length,
                                      promptText: item.promptText,
                                      assetPath: data?.sound, // 자동재생용 mp3
                                    ),
                              ),
                            );
                            if (ok == true && mounted) {
                              setState(() => _done[index] = true);
                            }
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
  final String title; // (번호 + 요약) — 큰 글씨 한 줄만 표시
  final String promptText; // 녹음 페이지로 넘길 실제 지문

  const _InterviewItem({
    required this.number,
    required this.title,
    required this.promptText,
  });
}
