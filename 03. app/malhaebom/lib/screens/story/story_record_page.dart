// lib/screens/story/story_record_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// 한 줄을 완료로 마킹(추가 저장)
  static Future<Set<int>> markDone(String title, int index) async {
    final set = await load(title);
    set.add(index);
    await save(title, set);
    return set;
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

  // ✅ repo.RoleLine으로 통일
  late final List<repo.RoleLine> _items; // 텍스트+오디오
  late final int _count;

  /// 화면 표시에 쓰는 완료 플래그
  late List<bool> recorded;

  /// 영구 저장소 기준의 완료 인덱스(0-based)
  Set<int> _doneSet = <int>{};

  bool _loaded = false; // prefs 로딩 완료 여부

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
      // 만약 getRolePlayItems 반환 타입이 List<Map>이라면 아래처럼 매핑하세요:
      // temp = repo.FairytaleRepo.getRolePlayItems(widget.title)
      //     .map<repo.RoleLine>((m) => repo.RoleLine(text: m['text'], sound: m['sound']))
      //     .toList(growable: false);
    }

    // 3) 둘 다 비었을 때만 totalLines(혹은 1)로 placeholder 생성
    if (temp.isEmpty) {
      final fallbackCount = widget.totalLines ?? 1;
      temp = List<repo.RoleLine>.generate(
        fallbackCount,
        (i) =>
            repo.RoleLine(text: '${i + 1}번 대사의 스크립트가 여기에 표시됩니다.', sound: null),
      );

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

    // 일단 전부 false로 구성해 두고,
    recorded = List<bool>.filled(_count, false);

    // 이후 prefs에서 실제 완료 집합을 읽어 반영(비동기)
    _loadRecordedFromPrefs();
  }

  Future<void> _loadRecordedFromPrefs() async {
    final set = await _RecordProgressStore.load(widget.title);
    if (!mounted) return;

    setState(() {
      _doneSet = set;
      for (final idx in _doneSet) {
        if (idx >= 0 && idx < recorded.length) {
          recorded[idx] = true;
        }
      }
      _loaded = true;
    });
  }

  /// 한 줄 완료 → 상태/디스크에 동시 반영
  Future<void> _markRecorded(int zeroBasedIndex) async {
    // 메모리 반영
    if (zeroBasedIndex >= 0 && zeroBasedIndex < recorded.length) {
      setState(() {
        recorded[zeroBasedIndex] = true;
        _doneSet.add(zeroBasedIndex);
      });
    }
    // 디스크 반영
    await _RecordProgressStore.save(widget.title, _doneSet);
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
          child:
              !_loaded
                  ? const Center(
                    child: CircularProgressIndicator(),
                  ) // prefs 로드 전 로딩
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
                              final item = _items[idx];
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
                                            totalLines:
                                                _count, // 진행바 최대값은 실제 개수
                                            lineText: item.text,
                                            lineAssetPath:
                                                item.sound, // 원본 오디오 경로(있으면)
                                          ),
                                    ),
                                  );
                                  // 녹음 저장까지 완료되었을 때만 true를 돌려받음
                                  if (ok == true) {
                                    // 메모리 + 디스크 동시 반영
                                    await _markRecorded(idx);
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
