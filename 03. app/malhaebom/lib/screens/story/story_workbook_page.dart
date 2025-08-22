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
  final List<int> originalIndices;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        centerTitle: true,
        title: Text(
          '${widget.title} 워크북',
          style: TextStyle(
            fontFamily: _kFont,
            color: Colors.white,
            fontSize: 22.sp,
            fontWeight: FontWeight.w400, // ✅ 얇게
            letterSpacing: -0.1, // 시각적으로 더 가볍게
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
                  fontWeight: FontWeight.w500, // ✅ 굵지 않음
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

            // 진행도
            Row(
              children: [
                _roundIndex(_index + 1, size: 34.w),
                SizedBox(width: 10.w),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 12.h,
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
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

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

  Widget _roundIndex(int n, {double? size}) {
    final s = size ?? 28.w;
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
          fontFamily: _kFont,
          fontWeight: FontWeight.w700,
          fontSize: (s * 0.46),
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
