// lib/screens/story/story_record_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// repo를 별칭으로 임포트하여 타입 충돌 방지
import '../../data/fairytale_repo.dart' as repo;

import 'story_recording_page.dart';

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

/// 간단 영구 저장소: '이 제목에서 몇 번 줄을 완료했는가'를 저장/복원
class _RecordProgressStore {
  static String _keyOf(String title) => 'recorded_lines_${title}';

  /// 완료 줄 인덱스(0-based) 집합 로드
  static Future<Set<int>> load(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyOf(title)) ?? const <String>[];
    return list.map(int.parse).toSet();
  }

  /// 완료 줄 인덱스(0-based) 집합 저장
  static Future<void> save(String title, Set<int> done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyOf(title),
      done.map((e) => e.toString()).toList(),
    );
  }
}

class _StoryRecordPageState extends State<StoryRecordPage> {
  // 스타일
  static const _bg = Color(0xFFF6F7FB);
  static const _card = Colors.white;
  static const _divider = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF202124);
  static const _textSub = Color(0xFF6B7280);
  static const _blue = Color(0xFF3B5BFF);

  // 저장 위치/파일명 규칙 (녹음 화면과 동일해야 함)
  static const String _recFolder = 'story_records';
  static const String _ext = '.m4a';

  int _bookIndexFromTitle(String title) {
    switch (title.trim()) {
      case '어머니의 벙어리 장갑':
        return 1;
      case '아버지와 결혼식':
        return 2;
      case '할머니와 바나나':
        return 3;
      case '아들의 호빵':
        return 4;
      default:
        return 0;
    }
  }

  Future<String> _filePathForLine(int oneBasedLine) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _recFolder));
    final key = '${_bookIndexFromTitle(widget.title)}-$oneBasedLine$_ext';
    return p.join(dir.path, key);
  }

  // ✅ repo.RoleLine으로 통일
  late final List<repo.RoleLine> _items; // 텍스트+오디오
  late final int _count;

  /// 화면 표시에 쓰는 완료 플래그
  late List<bool> recorded;

  /// 영구 저장소 기준의 완료 인덱스(0-based)
  Set<int> _doneSet = <int>{};

  bool _loaded = false; // 초기 로딩 완료 여부

  @override
  void initState() {
    super.initState();

    // 👇 temp에 모두 계산 후 마지막에 한 번만 _items에 대입
    List<repo.RoleLine> temp;

    // 1) 외부에서 lines가 오면 텍스트만으로 구성 (최우선)
    if (widget.lines != null && widget.lines!.isNotEmpty) {
      temp = widget.lines!
          .map((t) => repo.RoleLine(text: t, sound: null))
          .toList(growable: false);
    } else {
      // 2) repo에서 rolePlay 자동 추출(텍스트+사운드)
      temp = repo.FairytaleRepo.getRolePlayItems(widget.title);
    }

    // 3) 둘 다 비었을 때만 totalLines(혹은 1)로 placeholder 생성
    if (temp.isEmpty) {
      final fallbackCount = widget.totalLines ?? 1;
      temp = List<repo.RoleLine>.generate(
        fallbackCount,
        (i) =>
            repo.RoleLine(text: '${i + 1}번 대사의 스크립트가 여기에 표시됩니다.', sound: null),
      );
      // (알림 제거)
    }

    _items = temp; // ✅ 단 한 번만 초기화
    _count = _items.length;

    // 일단 전부 false로 구성해 두고,
    recorded = List<bool>.filled(_count, false);

    // 이후 prefs + 디스크에서 실제 완료 집합을 읽어 반영(비동기)
    _hydrateFromPrefsAndDisk();
  }

  /// prefs와 디스크 스캔 결과의 합집합으로 recorded 초기화
  Future<void> _hydrateFromPrefsAndDisk() async {
    final prefsSet = await _RecordProgressStore.load(widget.title);
    final diskSet = <int>{};

    // 디스크에 실제 파일이 있는지 1.._count 스캔
    for (int i = 1; i <= _count; i++) {
      final path = await _filePathForLine(i);
      if (await File(path).exists()) {
        diskSet.add(i - 1); // 0-based
      }
    }

    final union = <int>{...prefsSet, ...diskSet};

    if (!mounted) return;
    setState(() {
      _doneSet = union;
      for (final idx in _doneSet) {
        if (idx >= 0 && idx < recorded.length) {
          recorded[idx] = true;
        }
      }
      _loaded = true;
    });

    // 합집합을 prefs에 동기화(선택적이지만 이후 속도/일관성에 도움)
    await _RecordProgressStore.save(widget.title, union);
  }

  /// 한 줄만 디스크에서 다시 체크하여 반영 (녹음 화면에서 돌아올 때 호출)
  Future<void> _refreshOneFromDisk(int zeroBasedIndex) async {
    final i = zeroBasedIndex + 1; // 1-based
    final path = await _filePathForLine(i);
    final exists = await File(path).exists();

    if (!mounted) return;
    setState(() {
      recorded[zeroBasedIndex] = exists;
      if (exists) {
        _doneSet.add(zeroBasedIndex);
      } else {
        _doneSet.remove(zeroBasedIndex);
      }
    });
    await _RecordProgressStore.save(widget.title, _doneSet);
  }

  @override
  Widget build(BuildContext context) {
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: AppColors.btnColorDark,
          elevation: 0.5,
          centerTitle: true,
          // leadingWidth: 0,
          toolbarHeight: _appBarH(context),
          title: Text(
            '${widget.title} 연극',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textScaler: const TextScaler.linear(1.0),
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 380.w),
          child:
              !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
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
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                16.h,
                                16.w,
                                12.h,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '이야기 주인공의 대사 따라하기',
                                    textAlign: TextAlign.center,
                                    textScaler: const TextScaler.linear(1.0),
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
                                    textScaler: const TextScaler.linear(1.0),
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
                                        textScaler: const TextScaler.linear(
                                          1.0,
                                        ),
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
                                        textScaler: const TextScaler.linear(
                                          1.0,
                                        ),
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
                              final item = _items[idx];
                              return _LineRow(
                                number: idx + 1,
                                done: recorded[idx],
                                onTap: () async {
                                  await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => StoryRecordingPage(
                                            title: widget.title,
                                            lineNumber: idx + 1,
                                            totalLines: _count,
                                            lineText: item.text,
                                            lineAssetPath: item.sound,
                                          ),
                                    ),
                                  );
                                  // ✅ 돌아올 때, 해당 라인의 파일 존재 여부를 디스크에서 다시 확인
                                  await _refreshOneFromDisk(idx);
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
                    textScaler: const TextScaler.linear(1.0),
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
