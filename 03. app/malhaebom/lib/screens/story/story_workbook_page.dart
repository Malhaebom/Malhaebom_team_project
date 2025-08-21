import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';
import 'workbook_result_page.dart';

/// ===== 모델 =====
class WorkbookItem {
  final String title;
  final List<String> imageNames; // ex) ["1.png","2.png","3.png","4.png"]
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
/// - jsonAssetPath: JSON 파일 assets 경로 (예: 'assets/workbook/workbook.json')
/// - imageBaseDir : 이미지 베이스 경로 (예: 'assets/workbook/images')
/// - subsetIndices: 결과 화면에서 '틀린 문제만 다시 풀기'할 때 특정 인덱스만 풀도록
class StoryWorkbookPage extends StatefulWidget {
  final String title;
  final String jsonAssetPath;
  final String imageBaseDir;
  final List<int>? subsetIndices;

  const StoryWorkbookPage({
    super.key,
    required this.title,
    required this.jsonAssetPath,
    required this.imageBaseDir,
    this.subsetIndices,
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
    // 재도전: 특정 인덱스만
    return widget.subsetIndices!.map((i) => items[i]).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      minTextAdapt: true,
      builder: (_, __) {
        return FutureBuilder<List<WorkbookItem>>(
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
              // 원본 인덱스 맵(재도전 시 결과로 되돌릴 때 필요)
              originalIndices:
                  widget.subsetIndices ??
                      List<int>.generate(items.length, (i) => i),
            );
          },
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
  final List<int> originalIndices; // 이 세션에서의 i가 전체 몇 번 문제였는지

  const _WorkbookRunner({
    required this.title,
    required this.items,
    required this.imageBaseDir,
    required this.jsonAssetPath,
    required this.originalIndices,
  });

  @override
  State<_WorkbookRunner> createState() => _WorkbookRunnerState();
}

class _WorkbookRunnerState extends State<_WorkbookRunner> {
  int _index = 0;
  int? _selected; // 0~3
  late final List<int?> _selections; // 각 문항의 선택지 인덱스
  late final List<bool?> _corrects; // 각 문항 정오(null=안품)

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
      // 완료 → 결과 페이지
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkbookResultPage(
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

  // 테스트 페이지와 동일한 진행도 계산 (0~1)
  double get _progress =>
      widget.items.isEmpty ? 0 : (_index / widget.items.length).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        centerTitle: true,
        title: Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
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
                '${_index + 1}번 문제',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18.sp,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            SizedBox(height: 12.h),

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
                  color: Colors.white,
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // 2x2 이미지 그리드
            GridView.builder(
              shrinkWrap: true,
              itemCount: 4,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1,
              ),
              itemBuilder: (_, i) => _ImageChoiceTile(
                imgPath: '${widget.imageBaseDir}/${item.imageNames[i]}',
                selected: _selected == i,
                onTap: () => setState(() => _selected = i),
              ),
            ),

            SizedBox(height: 8.h),

            // 진행도 (테스트 페이지와 동일 스타일)
            Row(
              children: [
                _roundIndex(_index + 1, size: 30.w),
                SizedBox(width: 10.w),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10.h,
                      child: LayoutBuilder(
                        builder: (context, c) => Stack(
                          children: [
                            Container(width: c.maxWidth, color: const Color(0xFFE5E7EB)),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            SizedBox(height: 80.h), // FAB가 가리지 않도록 여백
          ],
        ),
      ),

      // 하단 고정 CTA 버튼 (테스트 페이지와 동일)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
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
              _index < widget.items.length - 1 ? '다음' : '완료',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp),
            ),
          ),
        ),
      ),
    );
  }

  // 테스트 페이지와 동일한 원형 라벨
  Widget _roundIndex(int n, {double? size}) {
    final s = size ?? 24.w;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: (s * 0.42),
          color: const Color(0xFF6B7280),
        ),
      ),
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
    final innerRadius = 12.r; // 외곽보다 조금 작게
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(outerRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(3), // 보더와 이미지 사이 여백
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(
            color: selected ? AppColors.btnColorDark : const Color(0xFFE5E7EB),
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
            errorBuilder: (_, __, ___) => Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: const Color(0xFF9CA3AF),
                size: 28.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
