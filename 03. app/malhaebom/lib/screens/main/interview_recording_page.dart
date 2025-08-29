// lib/screens/main/interview_recording_page.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FlutterError;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../data/interview_repo.dart';
import 'interview_result_page.dart'; // InterviewResultPage, CategoryStat
import 'interview_session.dart';

class _Line {
  final String text;
  final String? sound;
  const _Line(this.text, this.sound);
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

  // 편의 getter
  bool get _isLast => widget.lineNumber >= widget.totalLines;

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

  Future<String> _createTempRecordPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(
      dir.path,
      'ir_tmp_${widget.lineNumber}_${DateTime.now().millisecondsSinceEpoch}.m4a',
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
      // 스낵바 제거: 에셋 실패 시 로그만 남김
      if (mounted) setState(() => _isAssetPlaying = false);
      final full = (widget.assetPath ?? '').trim();
      if (full.isNotEmpty) {
        await _debugDumpAssets(contains: p.basename(full));
        final parent = p.basename(p.dirname(full));
        if (parent.isNotEmpty) await _debugDumpAssets(contains: parent);
      }
    } catch (e) {
      // 스낵바 제거: 재생 실패 시 로그만 남김
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
            // automaticallyImplyLeading: false,
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

  // ====== 녹음 제어 ======

  Future<void> _startRecording() async {
    if (_isRecording) return;
    if (_recordLocked) {
      // 스낵바 제거: 잠금 상태면 조용히 무시
      return;
    }

    if (_isAssetPlaying) {
      await _assetPlayer.stop();
      if (mounted) setState(() => _isAssetPlaying = false);
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      // 스낵바 제거: 권한 없음 시 조용히 무시(필요시 설정 페이지 유도 로직 추가 가능)
      return;
    }

    final tempPath = await _createTempRecordPath();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: tempPath,
    );

    _elapsed = Duration.zero;
    _startRecTimer();

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isMyPlaying = false;
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
    // 스낵바 제거: 시간 초과 메시지 없음
  }

  void _cancelRecTimer() {
    _recTimer?.cancel();
    _recTimer = null;
  }

  /// 공통 정지 + 완료 처리
  /// - 임시 파일 삭제
  /// - 세션 setDone 후, 세션에서 다시 진행도 로드하여 버튼 활성 상태 갱신
  Future<void> _stopRecording() async {
    _cancelRecTimer();
    final path = await _recorder.stop();

    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _savedPath = null;
    });

    // 세션에 저장(대기)
    await InterviewSession.setDone(
      widget.lineNumber - 1,
      true,
      widget.totalLines,
    );

    // 저장 이후 세션에서 최신 진행도 로드 → 버튼 활성 상태 갱신
    final progress = await InterviewSession.getProgress(widget.totalLines);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _thisDone =
          (progress.length >= widget.totalLines)
              ? progress[widget.lineNumber - 1]
              : true; // 방어: 최소한 true
      _prevAllDone = _calcPrevAllDone(progress);
    });
  }

  Future<void> _finishRecording() async {
    if (_recordLocked) return;

    if (_isRecording) {
      await _stopRecording(); // 정지 + 저장 + 재로딩
      if (!mounted) return;
      setState(() => _recordLocked = true);
      // 스낵바 제거: 종료 안내 없음
    } else {
      if (_thisDone) {
        setState(() => _recordLocked = true);
        // 스낵바 제거: 이미 완료 안내 없음
      } else {
        // 스낵바 제거: 먼저 녹음 시작 안내 없음
      }
    }
  }

  Future<void> _goNext() async {
    if (_isRecording) {
      await _stopRecording();
      return;
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

  Future<void> _goResult() async {
    if (_isRecording) await _stopRecording();
    if (!mounted) return;

    // TODO: 실제 분석 결과 값으로 교체
    final now = DateTime.now();
    final dummyCat = <String, CategoryStat>{
      '요구': const CategoryStat(correct: 0, total: 0),
      '질문': const CategoryStat(correct: 0, total: 0),
      '단언': const CategoryStat(correct: 0, total: 0),
      '의례화': const CategoryStat(correct: 0, total: 0),
    };
    final dummyType = <String, CategoryStat>{
      '직접화행': const CategoryStat(correct: 0, total: 0),
      '간접화행': const CategoryStat(correct: 0, total: 0),
      '질문화행': const CategoryStat(correct: 0, total: 0),
      '단언화행': const CategoryStat(correct: 0, total: 0),
      '의례화화행': const CategoryStat(correct: 0, total: 0),
    };

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => InterviewResultPage(
              score: 0,
              total: 0,
              byCategory: dummyCat,
              byType: dummyType,
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
