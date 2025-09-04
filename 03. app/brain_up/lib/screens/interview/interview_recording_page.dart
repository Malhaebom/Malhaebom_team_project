// lib/screens/main/interview_recording_page.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FlutterError;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:brain_up/theme/colors.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // ✅ MediaType
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/interview_repo.dart';
import 'interview_result_page.dart'; // InterviewResultPage, CategoryStat
import 'interview_session.dart';

class _Line {
  final String text;
  final String? sound;
  const _Line(this.text, this.sound);
}

const bool kShowAnalyzeBanner = false; // ← 배너 완전 숨김

/// ===== 서버 연동 설정 =====
const bool kUseServer = bool.fromEnvironment('USE_SERVER', defaultValue: true);
final String API_BASE =
    (() {
      const defined = String.fromEnvironment('API_BASE', defaultValue: '');
      if (defined.isNotEmpty) return defined;
      // 서버 문서와 동일: 게이트웨이 4000
      return 'http://127.0.0.1:4000';
    })();
const String _ANALYZE_PATH = '/ir/analyze'; // 게이트웨이 분석 엔드포인트

/// 항목 만점(문서 기준 40점 체계)
const Map<String, int> _MAX_PER_KEY = {
  '반응 시간': 4,
  '반복어 비율': 4,
  '평균 문장 길이': 4,
  '화행 적절성': 12,
  '회상어 점수': 8, // 문서의 "회상성"을 앱 키 "회상어 점수"로 표준화
  '문법 완성도': 8,
};

/// 서버/문서 키 → 앱 내부 표준 키 매핑
String _stdKey(String raw) {
  final k = raw.trim();
  switch (k) {
    case '회상성':
    case '회상 점수':
      return '회상어 점수';
    case '화행 적절성 점수':
      return '화행 적절성';
    case '문장 길이':
      return '평균 문장 길이';
    case '반복어':
      return '반복어 비율';
    default:
      return k;
  }
}

/// ===== 결과 집계(SharedPreferences) =====
/// - 질문별 분석 결과를 누적 저장 → 마지막에 합산해서 결과 페이지로 전달
class _AggStore {
  static const _kScore = 'ir_aggr_score';
  static const _kTotal = 'ir_aggr_total';
  static const _kCat = 'ir_aggr_byCategory';
  static const _kType = 'ir_aggr_byType';
  static const _kCount = 'ir_aggr_count';

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kScore);
    await prefs.remove(_kTotal);
    await prefs.remove(_kCat);
    await prefs.remove(_kType);
    await prefs.remove(_kCount);
  }

  static Future<void> add({
    required int score,
    required int total,
    required Map<String, Map<String, int>> byCategory,
    Map<String, Map<String, int>>? byType,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ 카테고리: 누적만 (캡 금지)
    final Map<String, dynamic> curCat =
        (prefs.getString(_kCat) != null)
            ? jsonDecode(prefs.getString(_kCat)!)
            : {};
    byCategory.forEach((k, v) {
      final std = _stdKey(k);
      final existed =
          (curCat[std] is Map) ? Map<String, dynamic>.from(curCat[std]) : {};
      final c0 = (existed['correct'] ?? 0) as int;
      final t0 = (existed['total'] ?? 0) as int;

      final addC = (v['correct'] ?? 0);
      final addT = (v['total'] ?? (_MAX_PER_KEY[std] ?? 0)); // 보통 카테고리 만점

      curCat[std] = {'correct': c0 + addC, 'total': t0 + addT};
    });
    await prefs.setString(_kCat, jsonEncode(curCat));

    // 타입(동화키) 누적은 그대로
    if (byType != null) {
      final Map<String, dynamic> curType =
          (prefs.getString(_kType) != null)
              ? jsonDecode(prefs.getString(_kType)!)
              : {};
      byType.forEach((k, v) {
        final existed =
            (curType[k] is Map) ? Map<String, dynamic>.from(curType[k]) : {};
        final c0 = (existed['correct'] ?? 0) as int;
        final t0 = (existed['total'] ?? 0) as int;
        curType[k] = {
          'correct': c0 + (v['correct'] ?? 0),
          'total': t0 + (v['total'] ?? 0),
        };
      });
      await prefs.setString(_kType, jsonEncode(curType));
    }

    // ✅ 여기서는 총점/분모를 저장하지 않음(정규화는 take()에서만)
    await prefs.setInt(_kCount, (prefs.getInt(_kCount) ?? 0) + 1);
  }

  static Future<
    ({
      int score,
      int total,
      int count,
      Map<String, Map<String, int>> byCategory,
      Map<String, Map<String, int>> byType,
    })
  >
  take({int? expectedCount}) async {
    // expectedCount로 미수신 패딩
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> cat =
        (prefs.getString(_kCat) != null)
            ? jsonDecode(prefs.getString(_kCat)!)
            : {};
    final Map<String, dynamic> typ =
        (prefs.getString(_kType) != null)
            ? jsonDecode(prefs.getString(_kType)!)
            : {};
    final count = prefs.getInt(_kCount) ?? 0;

    final int padCount =
        (expectedCount != null && expectedCount > count)
            ? (expectedCount - count)
            : 0; // 미수신 문항 수

    // ✅ 카테고리: accCorrect/accTotal → (미수신*maxPerItem)만큼 분모에 패딩 → 카테고리 만점으로 재스케일 → 카테고리 만점으로 재스케일
    int scoreNorm = 0;
    final Map<String, Map<String, int>> catOut = {};
    _MAX_PER_KEY.forEach((key, maxPerItem) {
      final m = (cat[key] is Map) ? Map<String, dynamic>.from(cat[key]) : {};
      final accC = (m['correct'] ?? 0) as int;
      final accT = (m['total'] ?? 0) as int;
      // NEW: 미수신(못 받은) 문항은 correct=0, total=해당 카테고리 만점으로 간주 → 분모 패딩
      final adjDen = accT + padCount * maxPerItem;
      final ratio = accT > 0 ? (accC / accT) : 0.0;
      final normC = (ratio * maxPerItem).round(); // 0..maxPerItem
      catOut[key] = {'correct': normC, 'total': maxPerItem};
      scoreNorm += normC;
    });
    final totalNorm = _MAX_PER_KEY.values.fold<int>(
      0,
      (a, b) => a + b,
    ); // 항상 40

    // 타입(동화키)은 누적합 그대로 사용 (별도 만점체계 없음)
    final Map<String, Map<String, int>> typeOut = {};
    typ.forEach((k, v) {
      final m = Map<String, dynamic>.from(v);
      typeOut[k] = {
        'correct': (m['correct'] ?? 0) as int,
        'total': (m['total'] ?? 0) as int,
      };
    });

    // 비움
    await clear();

    return (
      score: scoreNorm,
      total: totalNorm,
      count: count,
      byCategory: catOut,
      byType: typeOut,
    );
  }
}

class InterviewRecordingPage extends StatefulWidget {
  final int lineNumber; // 1..N
  final int totalLines; // N
  final String promptText;

  final String? assetPath;
  final String? audioUrl;
  final List<int>? mp3Bytes;

  const InterviewRecordingPage({
    Key? key,
    required this.lineNumber,
    required this.totalLines,
    required this.promptText,
    this.assetPath,
    this.audioUrl,
    this.mp3Bytes,
  }) : super(key: key);

  @override
  State<InterviewRecordingPage> createState() => _InterviewRecordingPageState();
}

class _InterviewRecordingPageState extends State<InterviewRecordingPage>
    with SingleTickerProviderStateMixin {
  // 스타일
  static const kBlue = Color(0xFF344CB7);
  static const kBg = Color(0xFFF6F7FB);
  static const kSliderTrack = Color(0xFFE5E7EB);
  static const kGreyNum = Color(0xFF9CA3AF);

  static const Duration _kResultMaxWait = Duration(
    minutes: 1,
  ); // ★ NEW: 결과 대기 최대 1분

  // 녹음 제한
  static const Duration _kMaxRecord = Duration(seconds: 30);
  Timer? _recTimer;
  Duration _elapsed = Duration.zero;

  // 재녹음 잠금
  bool _recordLocked = false;

  // 진행도(세션 기반)
  List<bool> _progress = const [];
  bool _thisDone = false; // 현재 라인 완료 여부(세션)
  bool _prevAllDone = false; // 마지막 페이지에서 이전 라인 모두 완료 여부(세션)

  // 오디오
  final _recorder = AudioRecorder();
  final _myPlayer = AudioPlayer();
  final _assetPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isMyPlaying = false;
  bool _isAssetPlaying = false;

  String? _savedPath;

  // 상단 진행 애니메이션
  late final AnimationController _ctrl;
  late final Animation<double> _sliderAnim;
  late double _sliderValue;

  // 분석 상태
  bool _isAnalyzing = false; // 현재 라인 분석중
  bool _lineAnalyzed = false; // 현재 라인 분석 완료 여부
  String? _analyzeError; // 에러 메시지

  // 편의 getter
  bool get _isLast => widget.lineNumber >= widget.totalLines;

  int _currentQuestionId() {
    final item = InterviewRepo.getByIndex(widget.lineNumber - 1);
    return item?.number ?? widget.lineNumber; // assets에 명시된 id 우선, 없으면 i+1
  }

  @override
  void initState() {
    super.initState();

    // 슬라이더 (n-1) -> n
    final double start =
        (widget.lineNumber > 1 ? widget.lineNumber - 1 : 1).toDouble();
    final double end = widget.lineNumber.toDouble();
    _sliderValue = start;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sliderAnim = Tween<double>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.addListener(() => setState(() => _sliderValue = _sliderAnim.value));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());

    _myPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isMyPlaying = false);
    });
    _assetPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isAssetPlaying = false);
    });

    _initAsync(); // 비동기 초기화
  }

  Future<void> _initAsync() async {
    // 1) 세션 진행도 로드
    final progress = await InterviewSession.getProgress(widget.totalLines);
    final alreadyDone =
        (progress.length >= widget.totalLines)
            ? progress[widget.lineNumber - 1]
            : false;
    final allDone = await InterviewSession.isCompleted(widget.totalLines);

    if (!mounted) return;
    setState(() {
      _progress = progress;
      _thisDone = alreadyDone;
      _prevAllDone = _calcPrevAllDone(progress);
      // 회차 미완료 상태에서 이미 완료된 항목이면 재녹음 잠금
      _recordLocked = alreadyDone && !allDone;
    });

    // 2) 초기 자동 재생
    await _autoPlayOriginal();
  }

  // 마지막 페이지에서 이전(1..N-1) 라인이 모두 완료됐는지(세션 기준)
  bool _calcPrevAllDone(List<bool> p) {
    if (!_isLast) return false;
    if (p.length < widget.totalLines - 1) return false;
    for (int i = 0; i < widget.totalLines - 1; i++) {
      if (i == widget.lineNumber - 1) continue; // 방어
      if (i >= p.length || p[i] == false) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _cancelRecTimer();
    _ctrl.dispose();
    _myPlayer.stop();
    _myPlayer.dispose();
    _assetPlayer.stop();
    _assetPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  _Line? _lineFor(int n) {
    final d = InterviewRepo.getByIndex(n - 1);
    if (d == null) return null;
    return _Line(d.speechText, d.sound);
  }

  Future<void> _debugDumpAssets({String? contains}) async {
    try {
      final jsonStr = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(jsonStr);
      Iterable<String> keys = manifest.keys;
      if (contains != null && contains.isNotEmpty) {
        keys = keys.where((k) => k.contains(contains));
      }
      final list = keys.toList()..sort();
      debugPrint('===== [ASSETS] ${contains ?? "ALL"} count=${list.length}');
      for (final k in list) debugPrint(k);
    } catch (e) {
      debugPrint('AssetManifest load failed: $e');
    }
  }

  String _ensureAssetFullPath(String raw) {
    return raw.startsWith('assets/') ? raw : 'assets/$raw';
  }

  String _toAssetKey(String rawOrFull) {
    return rawOrFull.startsWith('assets/')
        ? rawOrFull.substring('assets/'.length)
        : rawOrFull;
  }

  Future<String> _writeTempMp3(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'interview_tmp_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  // ✅ 녹음 파일을 WAV로 저장
  Future<String> _createTempRecordPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(
      dir.path,
      'ir_tmp_${widget.lineNumber}_${DateTime.now().millisecondsSinceEpoch}.wav', // ← .wav
    );
  }

  // 원본 오디오 자동 재생
  Future<void> _autoPlayOriginal() async {
    if (_isRecording) await _stopRecording();
    await _myPlayer.stop();
    if (mounted) setState(() => _isMyPlaying = false);

    try {
      if (widget.mp3Bytes != null && widget.mp3Bytes!.isNotEmpty) {
        final path = await _writeTempMp3(Uint8List.fromList(widget.mp3Bytes!));
        await _assetPlayer.stop();
        await _assetPlayer.play(DeviceFileSource(path));
      } else if (widget.audioUrl != null &&
          widget.audioUrl!.trim().isNotEmpty) {
        await _assetPlayer.stop();
        await _assetPlayer.play(UrlSource(widget.audioUrl!.trim()));
      } else if (widget.assetPath != null &&
          widget.assetPath!.trim().isNotEmpty) {
        final full = _ensureAssetFullPath(widget.assetPath!.trim());
        final key = _toAssetKey(full);
        await rootBundle.load(full); // 존재 확인
        await _assetPlayer.stop();
        await _assetPlayer.play(AssetSource(key));
      } else {
        return;
      }
      if (mounted) setState(() => _isAssetPlaying = true);
    } on FlutterError {
      if (mounted) setState(() => _isAssetPlaying = false);
      final full = (widget.assetPath ?? '').trim();
      if (full.isNotEmpty) {
        await _debugDumpAssets(contains: p.basename(full));
        final parent = p.basename(p.dirname(full));
        if (parent.isNotEmpty) await _debugDumpAssets(contains: parent);
      }
    } catch (e) {
      debugPrint('오디오 재생 실패: $e');
      if (mounted) setState(() => _isAssetPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasNext = widget.lineNumber < widget.totalLines;

    // ✅ 페이지 전체 글자 크기 고정
    final fixedTextScale = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return MediaQuery(
      data: fixedTextScale,
      child: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, _thisDone); // 리스트에 true/false 전달
          return false;
        },
        child: Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: AppColors.btnColorDark,
            elevation: 0.5,
            centerTitle: true,
            toolbarHeight: _appBarH(context),
            title: Text(
              '인지 검사',
              style: TextStyle(
                fontFamily: 'GmarketSans',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: Colors.white,
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420.w),
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
                children: [
                  // 지문
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 22.w,
                      vertical: 18.h,
                    ),
                    decoration: BoxDecoration(
                      color: kBlue,
                      borderRadius: BorderRadius.circular(22.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.promptText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w500,
                        fontSize: 20.sp,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 22.h),

                  // 큰 원형 녹음 버튼
                  Center(
                    child: GestureDetector(
                      onTap:
                          (_isRecording || _recordLocked)
                              ? null
                              : _startRecording,
                      child: Opacity(
                        opacity: (_isRecording || _recordLocked) ? 0.6 : 1.0,
                        child: Container(
                          width: 320.w,
                          height: 320.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: kBlue, width: 16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _isRecording
                                ? '${_fmt(_elapsed)}\n/ ${_fmt(_kMaxRecord)}'
                                : (_recordLocked ? '재녹음 불가' : '녹음\n시작'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              fontWeight: FontWeight.w400,
                              fontSize: 38.sp,
                              color: kBlue,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  if (kShowAnalyzeBanner &&
                      (_isAnalyzing ||
                          _lineAnalyzed ||
                          _analyzeError != null)) ...[
                    _analyzeStatus(),
                    SizedBox(height: 12.h),
                  ],

                  // 버튼들
                  SizedBox(
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed:
                          _isLast
                              ? ((_prevAllDone && _thisDone) ? _goResult : null)
                              : (hasNext && _thisDone ? _goNext : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD400),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                        textStyle: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w800,
                          fontSize: 22.sp,
                        ),
                      ),
                      child: Text(_isLast ? '결과 보러 가기' : '다 음'),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: _recordLocked ? null : _finishRecording,
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                final scheme = Theme.of(context).colorScheme;
                                return scheme.onSurface.withOpacity(0.12);
                              }
                              return const Color(0xFFFFD400);
                            }),
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                final scheme = Theme.of(context).colorScheme;
                                return scheme.onSurface.withOpacity(0.38);
                              }
                              return Colors.black;
                            }),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        elevation: MaterialStateProperty.all<double>(0),
                        textStyle: MaterialStateProperty.all<TextStyle>(
                          TextStyle(
                            fontFamily: 'GmarketSans',
                            fontWeight: FontWeight.w400,
                            fontSize: 22.sp,
                          ),
                        ),
                      ),
                      child: const Text('녹음 끝내기'),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  // 진행 표시
                  Row(
                    children: [
                      _numberBadge(
                        '${_sliderValue.round().clamp(1, widget.totalLines)}',
                        active: true,
                      ),
                      Expanded(
                        child: IgnorePointer(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              inactiveTrackColor: kSliderTrack,
                              activeTrackColor: kBlue,
                              thumbColor: kBlue,
                              overlayColor: kBlue.withOpacity(0.15),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: _sliderValue,
                              min: 1,
                              max: widget.totalLines.toDouble(),
                              divisions: (widget.totalLines - 1).clamp(1, 1000),
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                      ),
                      _numberBadge('${widget.totalLines}', active: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 분석 상태 표시
  Widget _analyzeStatus() {
    Color bg, border, text;
    String label;
    if (_isAnalyzing) {
      bg = const Color(0xFFEEF2FF);
      border = const Color(0xFFCBD5E1);
      text = const Color(0xFF1E40AF);
      label = '분석 중입니다...';
    } else if (_analyzeError != null) {
      bg = const Color(0xFFFFF1F2);
      border = const Color(0xFFFCA5A5);
      text = const Color(0xFFB91C1C);
      label = '분석 실패: ${_analyzeError!}';
    } else {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFF6EE7B7);
      text = const Color(0xFF065F46);
      label = '분석 완료';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            _isAnalyzing
                ? Icons.hourglass_bottom
                : (_analyzeError != null
                    ? Icons.error_outline
                    : Icons.check_circle_outline),
            size: 20.sp,
            color: text,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'GmarketSans',
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== 녹음 제어 ======

  Future<void> _startRecording() async {
    if (_isRecording) return;
    if (_recordLocked) {
      return;
    }

    if (_isAssetPlaying) {
      await _assetPlayer.stop();
      if (mounted) setState(() => _isAssetPlaying = false);
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      return;
    }

    final tempPath = await _createTempRecordPath();

    // ✅ WAV(PCM) 16kHz / Mono 로 녹음
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav, // ← m4a → wav
        sampleRate: 16000, // ← 16kHz
        numChannels: 1, // ← mono
        // bitRate: (WAV/PCM에는 의미 없음)
      ),
      path: tempPath,
    );

    _elapsed = Duration.zero;
    _startRecTimer();

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isMyPlaying = false;
        _lineAnalyzed = false;
        _analyzeError = null;
      });
    }
  }

  void _startRecTimer() {
    _cancelRecTimer();
    _recTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      final next = _elapsed + const Duration(seconds: 1);
      if (next >= _kMaxRecord) {
        setState(() => _elapsed = _kMaxRecord);
        t.cancel();
        await _autoStopByLimit();
      } else {
        setState(() => _elapsed = next);
      }
    });
  }

  Future<void> _autoStopByLimit() async {
    if (_isRecording) {
      await _stopRecording();
    }
    if (!mounted) return;
    setState(() {
      _recordLocked = true;
    });
  }

  void _cancelRecTimer() {
    _recTimer?.cancel();
    _recTimer = null;
  }

  /// 공통 정지 + 완료 처리
  /// - 임시 파일 **삭제하지 않음**(분석 업로드에 사용)
  /// - 세션 setDone 후 버튼 활성 상태 갱신
  Future<void> _stopRecording() async {
    _cancelRecTimer();
    final path = await _recorder.stop();

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _savedPath = path; // 파일 유지(업로드용)
    });

    // 세션 완료 표시
    await InterviewSession.setDone(
      widget.lineNumber - 1,
      true,
      widget.totalLines,
    );

    final progress = await InterviewSession.getProgress(widget.totalLines);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _thisDone =
          (progress.length >= widget.totalLines)
              ? progress[widget.lineNumber - 1]
              : true;
      _prevAllDone = _calcPrevAllDone(progress);
    });

    // 녹음 종료 후 자동 분석(1초 후)
    Future.delayed(const Duration(seconds: 1), _triggerAutoAnalyze);
  }

  Future<void> _finishRecording() async {
    if (_recordLocked) return;

    if (_isRecording) {
      await _stopRecording();
      if (!mounted) return;
      setState(() => _recordLocked = true);
    } else {
      if (_thisDone) {
        setState(() => _recordLocked = true);
      } else {
        // 아직 녹음 전
      }
    }
  }

  // ===== 분석 업로드 =====

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('auth_token') ?? '').trim();
    String userKey = (prefs.getString('user_key') ?? '').trim();
    final loginId = (prefs.getString('login_id') ?? '').trim();
    if (userKey.isEmpty && loginId.isNotEmpty) {
      userKey = loginId;
      await prefs.setString('user_key', userKey);
    }
    return {
      'accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userKey.isNotEmpty) 'x-user-key': userKey,
    };
  }

  Future<String> _loadUserKey() async {
    final prefs = await SharedPreferences.getInstance();
    final loginId = (prefs.getString('login_id') ?? '').trim();
    if (loginId.isNotEmpty) return loginId;
    final userKey = (prefs.getString('user_key') ?? '').trim();
    return userKey.isNotEmpty ? userKey : 'guest';
  }

  Future<void> _triggerAutoAnalyze() async {
    if (!mounted) return;
    if (!kUseServer) return;
    if (_savedPath == null || _lineAnalyzed || _isAnalyzing) return;

    // 콘솔 로그: 분석 시작
    print(
      '[IR] ▶ 분석 시작 | line=${widget.lineNumber}/${widget.totalLines} | qid=${widget.lineNumber} | path=$_savedPath',
    );

    setState(() {
      _isAnalyzing = true;
      _analyzeError = null;
    });

    try {
      await _sendForAnalysis(_savedPath!);

      // 콘솔 로그: 분석 완료
      print('[IR] ✓ 분석 완료 | line=${widget.lineNumber}');

      if (!mounted) return;
      setState(() {
        _lineAnalyzed = true;
      });

      try {
        await File(_savedPath!).delete();
      } catch (_) {}
      _savedPath = null;
    } catch (e) {
      // 콘솔 로그: 분석 실패
      print('[IR] ✗ 분석 실패 | line=${widget.lineNumber} | error=$e');

      if (!mounted) return;
      setState(() {
        _analyzeError = '$e';
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _sendForAnalysis(String path) async {
    final headers = await _authHeaders();
    final userKey = await _loadUserKey();

    final qid = widget.lineNumber;

    final base = Uri.parse(API_BASE + _ANALYZE_PATH);
    final uri =
        (userKey.isEmpty)
            ? base
            : base.replace(
              queryParameters: {
                'userKey': userKey,
                'lineNumber': '${widget.lineNumber}',
                'totalLines': '${widget.totalLines}',
                'questionId': '$qid',
              },
            );

    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(headers);
    req.fields['prompt'] = widget.promptText;
    req.fields['interviewTitle'] = '인지 능력 검사';
    req.fields['question_id'] = '$qid';
    req.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        path,
        filename: p.basename(path),
        // ✅ WAV 업로드
        contentType: MediaType('audio', 'wav'),
      ),
    );

    // ---- 업로드 & 응답 ----
    final streamed = await req.send().timeout(const Duration(seconds: 25));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw 'HTTP ${res.statusCode}';
    }

    Map<String, dynamic> jr;
    try {
      jr = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw '응답 파싱 실패';
    }

    // 게이트웨이 응답 형태 유연 처리
    // 1) 직접 합산형: { ok, score, total, byCategory:{키:{correct,total}}, byType:{...} }
    // 2) 점수형: { ok, scores:{키:점수}, types:{..}, totalMax:40 } 등
    if (jr['ok'] != true && jr['success'] != true) {
      if (jr['score'] == null &&
          jr['scores'] == null &&
          jr['byCategory'] == null) {
        throw '서버 처리 실패';
      }
    }

    // 표준화된 누적 입력 준비
    int score = 0;
    int total = 0;
    final Map<String, Map<String, int>> cat = {};
    Map<String, Map<String, int>>? typ;

    // (A) 서버가 이미 byCategory(한글)로 주는 경우
    if (jr['byCategory'] is Map) {
      final bc = Map<String, dynamic>.from(jr['byCategory']);
      bc.forEach((rawK, v) {
        final k = _stdKey(rawK);
        final m = Map<String, dynamic>.from(v);
        final c = (m['correct'] ?? 0) as int;
        final t = (m['total'] ?? (_MAX_PER_KEY[k] ?? 0)) as int;
        cat[k] = {'correct': c, 'total': t};
        score += c;
        total += t;
      });
    }

    // (A2) details(영문)만 오는 경우 → 한글 키로 매핑
    if (cat.isEmpty && jr['details'] is Map) {
      final det = Map<String, dynamic>.from(jr['details']);
      const mapEnToKo = {
        'response_time': '반응 시간',
        'repetition': '반복어 비율',
        'avg_sentence_length': '평균 문장 길이',
        'appropriateness': '화행 적절성',
        'recall': '회상어 점수',
        'grammar': '문법 완성도',
      };
      mapEnToKo.forEach((en, ko) {
        final t = _MAX_PER_KEY[ko] ?? 0;
        final v = det[en];
        final c = (v is num) ? v.toInt().clamp(0, t) : 0;
        cat[ko] = {'correct': c, 'total': t};
        score += c;
        total += t;
      });
    }

    // (B) scores(한글/영문 혼재)로 오는 경우
    if (cat.isEmpty && jr['scores'] is Map) {
      final sc = Map<String, dynamic>.from(jr['scores']);
      sc.forEach((rawK, v) {
        final k = _stdKey(rawK);
        final t = _MAX_PER_KEY[k] ?? 0;
        final c = (v is num) ? v.toInt().clamp(0, t) : 0;
        if (t > 0) {
          cat[k] = {'correct': c, 'total': t};
          score += c;
          total += t;
        }
      });
    }

    // 폴백: score/total만 있으면 그대로 쓰되, 어쨌든 add()에서 정규화됨
    if ((score == 0 && total == 0) &&
        (jr['score'] is num || jr['total'] is num)) {
      score = (jr['score'] as num?)?.toInt() ?? 0;
      total = (jr['total'] as num?)?.toInt() ?? 40;
    }

    await _AggStore.add(
      score: score,
      total: total,
      byCategory: cat,
      byType: typ,
    );
    print(
      '[IR]   byCategory=${cat.keys.map((k) => '$k:${cat[k]!['correct']}/${cat[k]!['total']}').join(', ')}',
    );
  }

  Future<void> _goNext() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    // 현재 라인 분석 미완이면 한번 더 시도(백업)
    if (kUseServer && !_lineAnalyzed) {
      await _triggerAutoAnalyze();
    }
    if (!mounted) return;

    final next = widget.lineNumber + 1;
    if (next > widget.totalLines) return;

    final nextLine = _lineFor(next);
    if (nextLine == null) return;

    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => InterviewRecordingPage(
              lineNumber: next,
              totalLines: widget.totalLines,
              promptText: nextLine.text,
              assetPath: nextLine.sound,
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder:
            (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  // -------------------- 교체할 _goResult --------------------
  Future<void> _goResult() async {
    if (_isRecording) {
      await _stopRecording();
    }
    // 마지막 라인 분석 보장
    if (kUseServer && !_lineAnalyzed) {
      await _triggerAutoAnalyze();
    }
    if (!mounted) return;

    if (!kUseServer) {
      // 서버 미사용 시 기존 로컬 합산으로 이동
      await _goResultFallbackLocal(expectedCount: widget.totalLines);
      return;
    }

    // 서버 진행도/결과 대기 → 실패 시 로컬 폴백
    try {
      await _waitAndShowServerResult();
    } catch (e) {
      debugPrint('서버 결과 대기 실패, 로컬 폴백: $e');
      await _goResultFallbackLocal(expectedCount: widget.totalLines);
    }
  }

  // -------------------- 신규: 서버 폴링 + 결과 수신 --------------------
  // -------------------- 신규: 서버 폴링 + 결과 수신 --------------------
  Future<void> _waitAndShowServerResult() async {
    final userKey = await _loadUserKey();
    const title = '인지 능력 검사';
    final start = DateTime.now();

    // 로딩 다이얼로그
    bool dialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => WillPopScope(
            onWillPop: () async => false,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 10),
                  ],
                ),
                width: 260.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: 12.h),
                    Text(
                      '결과가 분석중입니다...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    try {
      final total = widget.totalLines;

      // 1) 진행도: 모든 문항 서버 수신 대기 (단, 전체 60초 예산 내)
    while (true) {
      // ★ NEW: 60초 타임아웃 체크
      if (DateTime.now().difference(start) >= _kResultMaxWait) {
        print('[IR] ⏱ 진행도 대기 타임아웃 → 강제 마감(미수신=0점)');
        throw TimeoutException('progress wait > 60s');
      }

      try {
        final progUri = Uri.parse('$API_BASE/ir/progress')
            .replace(queryParameters: {'userKey': userKey, 'title': title});
        final resp = await http.get(progUri).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final jp = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
          final received = (jp['received'] ?? 0) as int;
          if (received >= total) break; // 전부 도착
        }
      } catch (_) {
        // 무시 후 재시도
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // 2) 최종 결과 수신 (단, 전체 60초 예산 내)
    Map<String, dynamic>? jr;
    while (true) {
      if (DateTime.now().difference(start) >= _kResultMaxWait) {
        print('[IR] ⏱ 결과 대기 타임아웃 → 강제 마감(미수신=0점)');
        throw TimeoutException('final result wait > 60s');
      }

      try {
        final resUri = Uri.parse('$API_BASE/ir/result')
            .replace(queryParameters: {'userKey': userKey, 'title': title});
        final res = await http.get(resUri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final tmp = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          if (tmp['ok'] == true && tmp['done'] == true) {
            jr = tmp;
            break;
          }
        }
      } catch (_) {
        // 무시 후 재시도
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }

    // 3) 결과 파싱 → 결과 페이지로 이동 (기존 그대로)
    if (!mounted) return;
    if (dialogShown) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogShown = false;
    }

    final int scoreSum = (jr!['score'] as num).toInt();
    final int totalSum = (jr['total'] as num).toInt();

    final Map<String, dynamic> byCatRaw = Map<String, dynamic>.from(jr['byCategory'] as Map);
    final Map<String, dynamic> byTypeRaw = Map<String, dynamic>.from((jr['byType'] ?? {}) as Map);

    final byCategory = <String, CategoryStat>{};
    byCatRaw.forEach((k, v) {
      final m = Map<String, dynamic>.from(v as Map);
      byCategory[k] = CategoryStat(
        correct: (m['correct'] as num).toInt(),
        total: (m['total'] as num).toInt(),
      );
    });

    final byType = <String, CategoryStat>{};
    if (byTypeRaw.isNotEmpty) {
      byTypeRaw.forEach((k, v) {
        final m = Map<String, dynamic>.from(v as Map);
        byType[k] = CategoryStat(
          correct: (m['correct'] as num).toInt(),
          total: (m['total'] as num).toInt(),
        );
      });
    } else {
      byType.addAll({
        '요구': const CategoryStat(correct: 0, total: 0),
        '질문': const CategoryStat(correct: 0, total: 0),
        '단언': const CategoryStat(correct: 0, total: 0),
        '의례화': const CategoryStat(correct: 0, total: 0),
      });
    }

    final now = DateTime.now();
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => InterviewResultPage(
          score: scoreSum,
          total: totalSum, // 40
          byCategory: byCategory,
          byType: byType,
          testedAt: now,
          interviewTitle: title,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  } catch (e) {
    // ★ NEW: 타임아웃/에러 → 강제 로컬 폴백(미수신=0점 패딩)
    debugPrint('서버 결과 대기 실패/타임아웃, 로컬 강제 마감: $e');
    if (mounted && dialogShown) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogShown = false;
    }
    await _goResultFallbackLocal(expectedCount: widget.totalLines); // ★ CHANGED
  }
}

  // -------------------- 신규: 로컬 합산 폴백(기존 로직 재사용) --------------------
  Future<void> _goResultFallbackLocal({int? expectedCount}) async {
    final ag = await _AggStore.take(expectedCount: expectedCount ?? widget.totalLines);

    int scoreSum = ag.score;
    int totalSum = ag.total;

    // byCategory → CategoryStat (6개 키 전부 보장)
    final byCategory = <String, CategoryStat>{};
    for (final key in _MAX_PER_KEY.keys) {
      final m = ag.byCategory[key];
      if (m == null) {
        byCategory[key] = CategoryStat(correct: 0, total: _MAX_PER_KEY[key]!);
      } else {
        byCategory[key] = CategoryStat(
          correct: m['correct']!,
          total: m['total']!,
        );
      }
    }

    // byType(있으면 전달, 없으면 0/0로 채움)
    final byType = <String, CategoryStat>{};
    if (ag.byType.isNotEmpty) {
      ag.byType.forEach((k, v) {
        byType[k] = CategoryStat(correct: v['correct']!, total: v['total']!);
      });
    } else {
      byType.addAll({
        '요구': const CategoryStat(correct: 0, total: 0),
        '질문': const CategoryStat(correct: 0, total: 0),
        '단언': const CategoryStat(correct: 0, total: 0),
        '의례화': const CategoryStat(correct: 0, total: 0),
      });
    }

    // 서버 실패 등으로 아무것도 없으면 폴백(임시 랜덤)
    if (scoreSum == 0 && totalSum == 0) {
      final now = DateTime.now();
      final rnd = math.Random();
      const cogKeys = [
        '반응 시간',
        '반복어 비율',
        '평균 문장 길이',
        '화행 적절성',
        '회상어 점수',
        '문법 완성도',
      ];
      int s = 0, t = 0;
      for (final k in cogKeys) {
        final max = _MAX_PER_KEY[k]!;
        final c = rnd.nextInt(max + 1);
        byCategory[k] = CategoryStat(correct: c, total: max);
        s += c;
        t += max;
      }
      scoreSum = s;
      totalSum = t;

      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder:
              (_, __, ___) => InterviewResultPage(
                score: scoreSum,
                total: totalSum,
                byCategory: byCategory,
                byType: byType,
                testedAt: now,
                interviewTitle: '인지 능력 검사(임시)',
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder:
              (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      );
      return;
    }

    final now = DateTime.now();
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => InterviewResultPage(
              score: scoreSum,
              total: totalSum,
              byCategory: byCategory,
              byType: byType,
              testedAt: now,
              interviewTitle: '인지 능력 검사',
            ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder:
            (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  // --- 뱃지/유틸 ---
  Widget _numberBadge(String text, {bool active = false}) {
    final Color bg = active ? kBlue : const Color(0xFFDFE3EA);
    final Color fg = active ? Colors.white : kGreyNum;
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'GmarketSans',
          fontWeight: FontWeight.w500,
          fontSize: 18.sp,
          color: fg,
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
