import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:brain_up/screens/story/story_test_result_page.dart';
import 'package:brain_up/screens/story/story_workbook_page.dart';
import 'package:brain_up/theme/colors.dart';

const String _kFont = 'GmarketSans';

/// 결과 페이지
class WorkbookResultPage extends StatefulWidget {
  final String title;
  final String jsonAssetPath; // 동일 JSON으로 재도전
  final List<WorkbookItem> items; // 이번 세션에 실제로 보여준(푼) 문제들(부분/전체)
  final String imageBaseDir;
  final List<int?> selections; // 각 문항 선택지(0~3) 또는 null
  final List<bool?> corrects; // 각 문항 정오(null=안품)
  final List<int> originalIndices; // 이 세션의 i가 전체 몇 번 문제인지(0-base)

  const WorkbookResultPage({
    super.key,
    required this.title,
    required this.jsonAssetPath,
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
  int? _totalCount; // JSON에서 읽어온 전체 문항 수
  late Map<int, bool?> _progress; // 원본 인덱스 → true/false/null(미응시)

  @override
  void initState() {
    super.initState();
    // 최초 상태: 이번 세션에서 가져온 결과를 맵에 쌓아둔다
    _progress = {
      for (var i = 0; i < widget.originalIndices.length; i++)
        widget.originalIndices[i]: widget.corrects[i],
    };
    _loadTotalCount();
  }

  Future<void> _loadTotalCount() async {
    _totalCount = await _computeTotalCountFromJson(widget.jsonAssetPath);
    if (mounted) setState(() {});
  }

  /// JSON 스키마가 달라도 최대한 안전하게 총 문항 수를 추정
  Future<int> _computeTotalCountFromJson(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw);
      if (data is List) return data.length;
      if (data is Map) {
        for (final key in ['items', 'list', 'data', 'questions', 'problems']) {
          final v = data[key];
          if (v is List) return v.length;
        }
      }
    } catch (_) {}
    // 실패 시, 이미 아는 범위로 폴백
    return widget.originalIndices.isEmpty
        ? 0
        : (widget.originalIndices.reduce((a, b) => a > b ? a : b) + 1);
  }

  // 재도전(단일/다중) 후 결과를 받아 현재 진행상태에 머지
  Future<void> _retakeAndMerge(List<int> subsetOriginalIndices) async {
    final ret = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => StoryWorkbookPage(
              title: widget.title,
              jsonAssetPath: widget.jsonAssetPath,
              imageBaseDir: widget.imageBaseDir,
              subsetIndices: subsetOriginalIndices,
              // ★ 추가 파라미터: 결과를 pop으로 되돌리도록
              returnResultToCaller: true,
            ),
      ),
    );

    if (!mounted) return;

    // 기대 타입: Map<int,bool> (원본 인덱스 → 정오)
    if (ret is Map && ret.isNotEmpty) {
      setState(() {
        ret.forEach((k, v) {
          if (k is int && (v is bool || v == null)) {
            _progress[k] = v as bool?;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const fixedScale = TextScaler.linear(1.0); // 전역 글자 스케일 고정
    final mq = MediaQuery.maybeOf(context) ?? const MediaQueryData();

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return MediaQuery(
      data: mq.copyWith(textScaler: fixedScale),
      child: Builder(
        builder: (context) {
          final totalCount =
              _totalCount ??
              (widget.originalIndices.isEmpty
                  ? 0
                  : (widget.originalIndices.reduce((a, b) => a > b ? a : b) +
                      1));

          // 현재까지 맞힌 개수
          final correctSoFar = _progress.values.where((v) => v == true).length;

          // 버튼 활성화 판단: 현재 진행상태에서 오답들만 추출
          final wrongOriginalIndices = <int>[
            for (final e in _progress.entries)
              if (e.value == false) e.key,
          ]..sort();

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.btnColorDark,
              centerTitle: true,
              // 오른쪽 X 제거, 왼쪽 뒤로가기만 사용
              toolbarHeight: _appBarH(context),
              title: Text(
                '${widget.title} 워크북',
                style: TextStyle(
                  fontFamily: 'GmarketSans',
                  color: Colors.white,
                  fontSize: 20.sp, // ↑
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '그림으로 쉽게 푸는 워크북',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22.sp, // ↑
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          '총 $totalCount문항 중 $correctSoFar문제 정답입니다.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22.sp, // ↑
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 10.h),

                        // 전설
                        Row(
                          children: [
                            _legendDot(
                              color: AppColors.btnColorDark,
                              label: '맞힌 문제',
                            ),
                            SizedBox(width: 12.w),
                            _legendX(
                              color: const Color(0xFFEF4444),
                              label: '틀린 문제',
                            ),
                          ],
                        ),
                        SizedBox(height: 14.h),

                        // 리스트: 항상 '전체 문항'을 그린다
                        ...List.generate(totalCount, (originalIdx) {
                          final state =
                              _progress[originalIdx]; // null/true/false
                          final isWrong = state == false;
                          final canRetakeThis = isWrong; // 오답만 단일 재도전 허용

                          return Column(
                            children: [
                              _ResultRow(
                                indexLabel: '${originalIdx + 1}번 문제',
                                state: state,
                                onTap:
                                    canRetakeThis
                                        ? () => _retakeAndMerge([originalIdx])
                                        : null,
                              ),
                              const Divider(height: 16),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),

                  // 틀린 문제만 다시 풀기
                  SizedBox(
                    height: 56.h, // ↑
                    child: ElevatedButton(
                      onPressed:
                          wrongOriginalIndices.isEmpty
                              ? null
                              : () => _retakeAndMerge(wrongOriginalIndices),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD43B),
                        disabledBackgroundColor: const Color(0xFFFFE8A3),
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        wrongOriginalIndices.isEmpty
                            ? '모든 문제를 맞혔어요!'
                            : '틀린 문제만 다시 풀기',
                        style: TextStyle(
                          fontFamily: _kFont,
                          fontWeight: FontWeight.w900,
                          fontSize: 20.sp, // ↑
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _legendDot({required Color color, required String label}) => Row(
    children: [
      Icon(Icons.circle_outlined, size: 20.sp, color: color),
      SizedBox(width: 4.w),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.sp,
          color: const Color(0xFF6B7280),
        ),
      ),
    ],
  );

  Widget _legendX({required Color color, required String label}) => Row(
    children: [
      Icon(Icons.close, size: 20.sp, color: color),
      SizedBox(width: 4.w),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.sp,
          color: const Color(0xFF6B7280),
        ),
      ),
    ],
  );

  Widget _legendHollow({required Color color, required String label}) => Row(
    children: [
      Icon(Icons.circle_outlined, size: 20.sp, color: color),
      SizedBox(width: 4.w),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.sp,
          color: const Color(0xFF6B7280),
        ),
      ),
    ],
  );
}

/// 한 줄(문항) 결과
class _ResultRow extends StatelessWidget {
  final String indexLabel;
  final bool? state; // true=정답, false=오답, null=미응시
  final VoidCallback? onTap;

  const _ResultRow({required this.indexLabel, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCorrect = state == true;
    final isWrong = state == false;
    final isUnanswered = state == null;

    IconData leading;
    Color color;

    if (isCorrect) {
      leading = Icons.circle_outlined;
      color = AppColors.btnColorDark;
    } else if (isWrong) {
      leading = Icons.close;
      color = const Color(0xFFEF4444);
    } else {
      leading = Icons.circle_outlined;
      color = const Color(0xFFCBD5E1);
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            Icon(leading, color: color, size: 26.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                indexLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18.sp,
                  color: isUnanswered ? const Color(0xFF9CA3AF) : Colors.black,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color:
                  onTap == null
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}
