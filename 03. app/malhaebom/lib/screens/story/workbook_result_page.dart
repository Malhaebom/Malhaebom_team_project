import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/screens/story/story_workbook_page.dart';
import 'package:malhaebom/theme/colors.dart';

/// 결과 페이지
class WorkbookResultPage extends StatefulWidget {
  final String title;
  final String jsonAssetPath;            // ★ 추가: 동일 JSON으로 재도전
  final List<WorkbookItem> items;        // 이번 세션에 풀었던 문제들(부분/전체)
  final String imageBaseDir;
  final List<int?> selections;           // 각 문항 선택지(0~3) 또는 null
  final List<bool?> corrects;            // 각 문항 정오(null=안품)
  final List<int> originalIndices;       // 이 세션의 i가 전체 몇 번 문제인지

  const WorkbookResultPage({
    super.key,
    required this.title,
    required this.jsonAssetPath,         // ★ 추가
    required this.items,
    required this.imageBaseDir,
    required this.selections,
    required this.corrects,
    required this.originalIndices,
  });

  @override
  State<WorkbookResultPage> createState() => _WorkbookResultPageState();
}

class _WorkbookResultPageState extends State<WorkbookResultPage> {
  @override
  Widget build(BuildContext context) {
    // 실제로 '푼' 로컬 인덱스만 필터
    final answeredLocal = <int>[];
    for (var i = 0; i < widget.items.length; i++) {
      if (widget.corrects[i] != null) answeredLocal.add(i);
    }

    // 정답/오답 집계(푼 것만)
    final totalAnswered = answeredLocal.length;
    final correctCount = answeredLocal.where((i) => widget.corrects[i] == true).length;

    // 오답(원본 인덱스 기준) 목록
    final wrongOriginalIndices = <int>[
      for (final i in answeredLocal)
        if (widget.corrects[i] == false) widget.originalIndices[i],
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        centerTitle: true,
        title: Text('${widget.title} 워크북',
            style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('그림으로 쉽게 푸는 워크북', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp)),
                  SizedBox(height: 8.h),
                  Text(
                    // 원본 번호 범위를 간단히 안내
                    '총 ${widget.originalIndices.length}문항 중 결과입니다.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18.sp, height: 1.2),
                  ),
                  SizedBox(height: 8.h),

                  // 전설: 맞힌/틀린만 (안 푼 문제 제거)
                  Row(children: [
                    _legendDot(color: AppColors.btnColorDark, label: '맞힌 문제'),
                    SizedBox(width: 10.w),
                    _legendX(color: const Color(0xFFEF4444), label: '틀린 문제'),
                  ]),
                  SizedBox(height: 12.h),

                  // 리스트: '푼 문제'만 노출
                  ...[
                    for (final i in answeredLocal) ...[
                      _ResultRow(
                        indexLabel: '${widget.originalIndices[i] + 1}번 문제',
                        state: widget.corrects[i], // true/false(둘 중 하나)
                        onTap: (widget.corrects[i] == false)
                            ? () async {
                                // 단일 문항 재도전: 해당 원본 인덱스만
                                final single = [widget.originalIndices[i]];
                                await Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StoryWorkbookPage(
                                      title: widget.title,
                                      jsonAssetPath: widget.jsonAssetPath,   // ★ 동일 JSON
                                      imageBaseDir: widget.imageBaseDir,
                                      subsetIndices: single,                 // ★ 원본 인덱스
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                      const Divider(height: 16),
                    ]
                  ],
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // 틀린 문제만 다시 풀기
            SizedBox(
              height: 52.h,
              child: ElevatedButton(
                onPressed: wrongOriginalIndices.isEmpty
                    ? null
                    : () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoryWorkbookPage(
                              title: widget.title,
                              jsonAssetPath: widget.jsonAssetPath,   // ★ 동일 JSON
                              imageBaseDir: widget.imageBaseDir,
                              subsetIndices: wrongOriginalIndices,   // ★ 원본 인덱스들
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD43B),
                  disabledBackgroundColor: const Color(0xFFFFE8A3),
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  wrongOriginalIndices.isEmpty ? '모든 문제를 맞혔어요!' : '틀린 문제만 다시 풀기',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp),
                ),
              ),
            ),

            SizedBox(height: 8.h),
            Center(
              child: Text(
                '정답: $correctCount / $totalAnswered',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, color: const Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot({required Color color, required String label}) => Row(children: [
        Icon(Icons.circle_outlined, size: 18.sp, color: color),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp, color: const Color(0xFF6B7280))),
      ]);

  Widget _legendX({required Color color, required String label}) => Row(children: [
        Icon(Icons.close, size: 18.sp, color: color),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp, color: const Color(0xFF6B7280))),
      ]);
}

/// 한 줄(문항) 결과
class _ResultRow extends StatelessWidget {
  final String indexLabel;
  final bool? state; // true=정답, false=오답
  final VoidCallback? onTap;

  const _ResultRow({required this.indexLabel, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCorrect = state == true;
    final leading = isCorrect ? Icons.circle_outlined : Icons.close;
    final color = isCorrect ? AppColors.btnColorDark : const Color(0xFFEF4444);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            Icon(leading, color: color, size: 24.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(indexLabel, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp)),
            ),
            Icon(Icons.chevron_right, color: onTap == null ? const Color(0xFFCBD5E1) : const Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
