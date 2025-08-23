import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FlutterError;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ★ 인터뷰 데이터 리포지토리 (경로는 프로젝트에 맞게 수정)
import '../../data/interview_repo.dart';

// 결과 페이지
import 'interview_result_page.dart'; // ← StoryResultPage / CategoryStat 사용

/// 간단한 진행 상태 (앱 생존 중 유지)
class _InterviewProgress {
  static final Set<int> doneLines = <int>{}; // 1..N 중 녹음 완료된 라인 번호
}

/// 리포지토리에서 꺼낸 한 줄 모델을 화면에서 쓰기 쉽게 래핑
class _Line {
  final String text;
  final String? sound; // assets 경로(ex. assets/interview/audio_0.mp3)
  const _Line(this.text, this.sound);
}

class InterviewRecordingPage extends StatefulWidget {
  final int lineNumber; // 1..N
  final int totalLines; // N
  final String promptText; // 현재 지문(바로 표시)

  // mp3 소스(중 하나만 들어와도 됨) — 보통은 assetPath만 씀
  final String? assetPath; // 에셋 mp3 (예: assets/interview/audio_0.mp3)
  final String? audioUrl; // 원격 mp3
  final List<int>? mp3Bytes; // 메모리상의 mp3 바이트

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
  // 색/스타일
  static const kBlue = Color(0xFF344CB7);
  static const kBg = Color(0xFFF6F7FB);
  static const kSliderTrack = Color(0xFFE5E7EB);
  static const kGreyNum = Color(0xFF9CA3AF);

  final _recorder = AudioRecorder();
  final _myPlayer = AudioPlayer(); // 내 녹음 재생(현재는 stop용으로만 사용)
  final _assetPlayer = AudioPlayer(); // 원본/URL/바이트 재생

  bool _isRecording = false;
  bool _isMyPlaying = false;
  bool _isAssetPlaying = false;

  // 파일은 실질적으로 저장하지 않지만, 기존 로직 호환을 위해 변수는 둔다(항상 null 유지)
  String? _savedPath;

  // 슬라이더 애니메이션
  late final AnimationController _ctrl;
  late final Animation<double> _sliderAnim;
  late double _sliderValue;

  @override
  void initState() {
    super.initState();

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

    // 페이지 진입 시 자동 재생
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlayOriginal());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _myPlayer.stop();
    _myPlayer.dispose();
    _assetPlayer.stop();
    _assetPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ==== 리포지토리 헬퍼 ====

  /// n(1-based)번째 줄의 지문/오디오를 리포지토리에서 가져온다.
  _Line? _lineFor(int n) {
    final d = InterviewRepo.getByIndex(n - 1); // repo는 0-based로 접근한다고 가정
    if (d == null) return null;
    return _Line(d.speechText, d.sound);
  }

  // ==== 유틸 ====
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

  // ★ 임시 녹음 파일 경로 생성 (정지 시 즉시 삭제해서 "저장 안 함"을 구현)
  Future<String> _createTempRecordPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(
      dir.path,
      'ir_tmp_${widget.lineNumber}_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
  }

  // ==== mp3 자동 재생 ====
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
        return; // 소스가 없으면 재생 안 함
      }

      if (mounted) setState(() => _isAssetPlaying = true);
    } on FlutterError {
      _showSnack('원본 오디오를 찾을 수 없어요.(에셋 경로 확인)');
      if (mounted) setState(() => _isAssetPlaying = false);
      final full = (widget.assetPath ?? '').trim();
      if (full.isNotEmpty) {
        await _debugDumpAssets(contains: p.basename(full));
        final parent = p.basename(p.dirname(full));
        if (parent.isNotEmpty) await _debugDumpAssets(contains: parent);
      }
    } catch (_) {
      _showSnack('오디오 재생에 실패했어요.');
      if (mounted) setState(() => _isAssetPlaying = false);
    }
  }

  // ==== 내부 판단값 ====
  bool get _isLast => widget.lineNumber >= widget.totalLines;

  /// 마지막 페이지에서 이전(1..N-1) 라인이 모두 완료됐는지
  bool _prevAllDone() {
    if (!_isLast) return false;
    for (int i = 1; i < widget.totalLines; i++) {
      if (!_InterviewProgress.doneLines.contains(i)) return false;
    }
    return true;
  }

  /// 현재 라인이 완료(녹음 종료)됐는지 — 파일 저장여부와 무관, 메모리 플래그만 사용
  bool get _thisLineDone =>
      _InterviewProgress.doneLines.contains(widget.lineNumber);

  /// 마지막 페이지에서 결과 버튼을 활성화할지 여부
  bool get _canFinishOnLast => _isLast && _prevAllDone() && _thisLineDone;

  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    final bool hasNext = widget.lineNumber < widget.totalLines;

    return Scaffold(
      backgroundColor: kBg,
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
            fontSize: 20.sp,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            // ▼ 파일은 저장하지 않으므로, 현재 라인 완료 여부를 반환
            onPressed: () => Navigator.pop(context, _thisLineDone),
            icon: const Icon(Icons.close),
            color: Colors.black87,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420.w),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
            children: [
              // 지문
              Container(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 18.h),
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

              // 큰 원형 녹음 버튼 (녹음 중엔 비활성)
              Center(
                child: GestureDetector(
                  onTap: _isRecording ? null : _startRecording, // ← 시작만 가능
                  child: Opacity(
                    opacity: _isRecording ? 0.6 : 1.0, // 시각적 비활성화
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
                        _isRecording ? '녹음\n중...' : '녹음\n시작',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w400, // 얇은 글씨
                          fontSize: 38.sp, // 크게
                          color: kBlue,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // 버튼들(세로): 다음 / 결과 보러 가기 / 녹음 끝내기
              SizedBox(
                height: 56.h,
                child: ElevatedButton(
                  // ★ 현재 라인 녹음 완료 전에는 비활성화
                  onPressed:
                      _isLast
                          ? (_canFinishOnLast ? _goResult : null)
                          : (hasNext && _thisLineDone ? _goNext : null),
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
                  // ★ pop하지 않고, 종료/삭제만 수행해서 '녹음 시작' 상태로 복귀
                  onPressed: _finishRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFC5CF), // 회색
                    foregroundColor: Colors.white, // 흰 글씨
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                    textStyle: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w400, // 얇은 글씨
                      fontSize: 22.sp,
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
    );
  }

  // ====== 녹음 제어 ======

  // 시작만 담당 (녹음 중이면 무시)
  Future<void> _startRecording() async {
    if (_isRecording) return;

    if (_isAssetPlaying) {
      await _assetPlayer.stop();
      if (mounted) setState(() => _isAssetPlaying = false);
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      _showSnack('마이크 권한이 필요해요.');
      return;
    }

    // ★ 경로 필수: 임시 경로를 생성해서 전달 (정지 시 즉시 삭제)
    final tempPath = await _createTempRecordPath();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: tempPath, // ← 필수
    );

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isMyPlaying = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop(); // 플랫폼이 만든 파일 경로

    // ★ 파일은 즉시 삭제해서 “저장 안 함”
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // 삭제 실패해도 앱 진행에는 영향 없음
      }
    }

    if (mounted) {
      setState(() {
        _isRecording = false; // 버튼 텍스트가 '녹음 시작'으로 복귀
        _savedPath = null; // 항상 null 유지
      });
      // 이 라인을 완료로 기록(파일 저장 없이 완료 처리)
      _InterviewProgress.doneLines.add(widget.lineNumber);
      // 마지막 화면이면 버튼 활성화 여부 재평가
      if (_isLast) setState(() {});
    }
  }

  // ★ '녹음 끝내기' 전용 핸들러 (화면 유지, 저장 안 하고 종료만)
  Future<void> _finishRecording() async {
    if (_isRecording) {
      await _stopRecording(); // 녹음 중이면 정지+삭제 → '녹음 시작'으로 돌아감
      _showSnack('녹음을 종료했어요. 파일은 저장하지 않았습니다.');
    } else {
      if (_thisLineDone) {
        _showSnack('이 라인의 녹음은 이미 완료 상태예요. 필요하면 다시 녹음할 수 있어요.');
      } else {
        _showSnack('먼저 동그라미를 눌러 녹음을 시작한 뒤 끝내기를 눌러주세요.');
      }
    }
  }

  // 다음
  Future<void> _goNext() async {
    if (_isRecording) {
      // 안전: 녹음 중엔 다음으로 못 넘어가지만, 혹시 누르면 정지 후 진행 막음
      await _stopRecording();
      return;
    }
    if (!mounted) return;

    final next = widget.lineNumber + 1;
    if (next > widget.totalLines) return;

    // 다음 줄의 "지문/오디오"를 데이터에서 다시 조회
    final nextLine = _lineFor(next);
    if (nextLine == null) return;

    // 동일 스택 누적을 피하려면 pushReplacement 권장
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => InterviewRecordingPage(
              lineNumber: next,
              totalLines: widget.totalLines,
              promptText: nextLine.text, // ← 다음 지문으로 교체
              assetPath: nextLine.sound, // ← 다음 오디오(있으면 자동재생)
            ),
      ),
    );
  }

  // 결과 페이지로 이동
  Future<void> _goResult() async {
    if (_isRecording) await _stopRecording();
    if (!mounted) return;

    // ★ 아직 알고리즘이 없으므로 placeholder 데이터로 이동
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

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => StoryResultPage(
              score: 0,
              total: 0,
              byCategory: dummyCat,
              byType: dummyType,
              testedAt: now,
              storyTitle: '회상 훈련',
            ),
      ),
    );
  }

  // 배지
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
