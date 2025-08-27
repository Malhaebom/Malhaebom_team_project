// lib/screens/story/story_workbook_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';
import 'workbook_result_page.dart';

const String _kFont = 'GmarketSans';

/// ===== 모델 =====
class WorkbookItem {
  final String title;
  final List<String> imageNames;
  final int answerIndex; // 0~3
  const WorkbookItem({
    required this.title,
    required this.imageNames,
    required this.answerIndex,
  });

  factory WorkbookItem.fromJson(Map<String, dynamic> j) => WorkbookItem(
    title: j['title'] as String,
    imageNames: (j['list'] as List).cast<String>(),
    answerIndex: j['answer'] as int,
  );
}

/// ===== 페이지 =====
class StoryWorkbookPage extends StatefulWidget {
  final String title;
  final String jsonAssetPath;
  final String imageBaseDir;
  final List<int>? subsetIndices;

  // 결과를 호출자(결과 페이지)로 되돌려줄지 여부
  final bool returnResultToCaller;

  const StoryWorkbookPage({
    super.key,
    required this.title,
    required this.jsonAssetPath,
    required this.imageBaseDir,
    this.subsetIndices,
    this.returnResultToCaller = false, // 기본은 기존 흐름 유지
  });

  @override
  State<StoryWorkbookPage> createState() => _StoryWorkbookPageState();
}

class _StoryWorkbookPageState extends State<StoryWorkbookPage> {
  late Future<List<WorkbookItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WorkbookItem>> _load() async {
    final raw = await rootBundle.loadString(widget.jsonAssetPath);
    final List list = jsonDecode(raw);
    final items =
        list.map((e) => WorkbookItem.fromJson(e)).toList().cast<WorkbookItem>();
    if (widget.subsetIndices == null) return items;
    return widget.subsetIndices!.map((i) => items[i]).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      minTextAdapt: true,
      builder: (_, __) {
        const fixedScale = TextScaler.linear(1.0); // 전역 글자 스케일 고정
        final mq = MediaQuery.maybeOf(context) ?? const MediaQueryData();
        return MediaQuery(
          data: mq.copyWith(textScaler: fixedScale),
          child: FutureBuilder<List<WorkbookItem>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snap.data!;
              return _WorkbookRunner(
                title: widget.title,
                items: items,
                imageBaseDir: widget.imageBaseDir,
                jsonAssetPath: widget.jsonAssetPath,
                originalIndices:
                    widget.subsetIndices ??
                    List<int>.generate(items.length, (i) => i),
                returnResultToCaller: widget.returnResultToCaller,
              );
            },
          ),
        );
      },
    );
  }
}

/// 실제 진행 위젯
class _WorkbookRunner extends StatefulWidget {
  final String title;
  final List<WorkbookItem> items;
  final String imageBaseDir;
  final String jsonAssetPath;
  final List<int> originalIndices;

  /// 결과를 pop으로 돌려줄지(재도전 플로우에서 사용)
  final bool returnResultToCaller;

  const _WorkbookRunner({
    required this.title,
    required this.items,
    required this.imageBaseDir,
    required this.jsonAssetPath,
    required this.originalIndices,
    this.returnResultToCaller = false,
  });

  @override
  State<_WorkbookRunner> createState() => _WorkbookRunnerState();
}

class _WorkbookRunnerState extends State<_WorkbookRunner> {
  int _index = 0;
  int? _selected;
  late final List<int?> _selections;
  late final List<bool?> _corrects;

  @override
  void initState() {
    super.initState();
    _selections = List<int?>.filled(widget.items.length, null, growable: false);
    _corrects = List<bool?>.filled(widget.items.length, null, growable: false);
  }

  void _submit() {
    final item = widget.items[_index];
    final sel = _selected;
    if (sel == null) return;

    final ok = sel == item.answerIndex;
    _selections[_index] = sel;
    _corrects[_index] = ok;

    if (_index < widget.items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      // 퀴즈가 끝나는 지점
      if (widget.returnResultToCaller) {
        // 재도전 흐름: 결과 페이지로 결과 맵(원본 인덱스 → 정오)을 돌려준다.
        final resultMap = <int, bool>{};
        for (var i = 0; i < _corrects.length; i++) {
          final c = _corrects[i];
          if (c != null) {
            final originalIndex = widget.originalIndices[i];
            resultMap[originalIndex] = c;
          }
        }
        Navigator.pop(context, resultMap); // 결과 페이지로 되돌림
        return;
      }

      // 기본 흐름: 결과 페이지로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => WorkbookResultPage(
                title: widget.title,
                jsonAssetPath: widget.jsonAssetPath,
                items: widget.items,
                imageBaseDir: widget.imageBaseDir,
                selections: _selections,
                corrects: _corrects,
                originalIndices: widget.originalIndices,
              ),
        ),
      );
    }
  }

  double get _progress =>
      widget.items.isEmpty ? 0 : (_index / widget.items.length).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];

    // 현재 문제의 "원본" 번호(1-base) — 상단 타이틀에만 사용
    final originalNo =
        (_index >= 0 && _index < widget.originalIndices.length)
            ? widget.originalIndices[_index] + 1
            : _index + 1;

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
        centerTitle: true,
        toolbarHeight: _appBarH(context),
        title: Text(
          '${widget.title} 워크북',
          style: TextStyle(
            fontFamily: _kFont,
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
          children: [
            SizedBox(height: 6.h),
            Center(
              child: Text(
                // 상단 문제 제목은 원본 번호를 유지
                '${originalNo}번 문제',
                style: TextStyle(
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 22.sp,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // 문제 박스
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: AppColors.btnColorDark,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _kFont,
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // 2x2 이미지 그리드
            GridView.builder(
              shrinkWrap: true,
              itemCount: 4,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: 1,
              ),
              itemBuilder:
                  (_, i) => _ImageChoiceTile(
                    imgPath: '${widget.imageBaseDir}/${item.imageNames[i]}',
                    selected: _selected == i,
                    onTap: () => setState(() => _selected = i),
                  ),
            ),

            SizedBox(height: 16.h),

            // ===== 진행도 (test_page 스타일, 동그라미 제거) =====
            _buildProgressBar(),

            SizedBox(height: 60.h),
          ],
        ),
      ),

      // 하단 버튼
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: SizedBox(
          width: double.infinity,
          height: 64.h,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD43B),
              disabledBackgroundColor: const Color(0xFFFFE8A3),
              foregroundColor: Colors.black,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: (_selected == null) ? null : _submit,
            child: Text(
              _index < widget.items.length - 1 ? '답안 제출' : '완료',
              style: TextStyle(
                fontFamily: _kFont,
                fontWeight: FontWeight.w900,
                fontSize: 20.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// test_page 진행바와 동일: 왼쪽 현재 번호(텍스트), 가운데 바, 오른쪽 총 문항 수
  Widget _buildProgressBar() {
    return Row(
      children: [
        // 현재 번호 (워크북 세션 내 인덱스)
        Text(
          '${_index + 1}',
          style: TextStyle(
            fontFamily: _kFont,
            fontWeight: FontWeight.w800,
            fontSize: 14.sp,
            color: AppColors.btnColorDark,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10.h, // test_page와 동일 높이
              child: LayoutBuilder(
                builder:
                    (context, c) => Stack(
                      children: [
                        Container(
                          width: c.maxWidth,
                          color: const Color(0xFFE5E7EB),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: c.maxWidth * _progress,
                          color: AppColors.btnColorDark,
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          '${widget.items.length}',
          style: TextStyle(
            fontFamily: _kFont,
            fontWeight: FontWeight.w700,
            fontSize: 14.sp,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

/// 이미지 선택 타일
class _ImageChoiceTile extends StatelessWidget {
  final String imgPath;
  final bool selected;
  final VoidCallback onTap;
  const _ImageChoiceTile({
    required this.imgPath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outerRadius = 16.r;
    final innerRadius = 12.r;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(outerRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(
            color: selected ? AppColors.btnColorDark : const Color(0xFFE5E7EB),
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Image.asset(
            imgPath,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: const Color(0xFF9CA3AF),
                    size: 30.sp,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
