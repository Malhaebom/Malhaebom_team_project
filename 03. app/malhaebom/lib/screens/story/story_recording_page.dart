// lib/screens/story/story_recording_page.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FlutterError;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 실제 녹음 화면(녹음/저장/재생 — DB 연결 없음)
class StoryRecordingPage extends StatefulWidget {
  final String title; // 동화 제목
  final int lineNumber; // 몇 번 대사인지(1..N)
  final int totalLines; // 총 대사 수(실제 개수로 전달)
  final String lineText; // 대사 내용
  /// pubspec.yaml에 선언된 "정확한" 경로. 예) assets/fairytale/어머니의벙어리/1/line01.mp3
  /// 또는 접두어 없이 fairytale/... 으로 들어와도 허용 (본 파일에서 보정)
  final String? lineAssetPath;

  const StoryRecordingPage({
    Key? key,
    required this.title,
    required this.lineNumber,
    required this.totalLines,
    required this.lineText,
    this.lineAssetPath,
  }) : super(key: key);

  @override
  State<StoryRecordingPage> createState() => _StoryRecordingPageState();
}

class _StoryRecordingPageState extends State<StoryRecordingPage>
    with SingleTickerProviderStateMixin {
  // --- 색상 상수 ---
  static const kBlue = Color(0xFF344CB7);
  static const kBg = Color(0xFFF6F7FB);
  static const kBubbleText = Colors.white;
  static const kListenYellow = Color(0xFFFFD400);
  static const kSliderTrack = Color(0xFFE5E7EB);
  static const kGreyNum = Color(0xFF9CA3AF);

  // --- 녹음/재생 상태 ---
  final _recorder = AudioRecorder();
  final _myPlayer = AudioPlayer(); // 내 녹음 재생
  final _assetPlayer = AudioPlayer(); // 원본(에셋) 재생

  bool _isRecording = false;
  bool _isMyPlaying = false;
  bool _isAssetPlaying = false;
  String? _savedPath; // 저장된 로컬 파일 경로

  // --- 슬라이더 애니메이션 ---
  late final AnimationController _ctrl;
  late final Animation<double> _sliderAnim;
  late double _sliderValue;

  @override
  void initState() {
    super.initState();

    // 슬라이더: (n-1) → n
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
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _myPlayer.dispose();
    _assetPlayer.dispose();
    _recorder.dispose();
    super.dispose();
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
      debugPrint('===== [ASSETS IN BUILD] filter: ${contains ?? "ALL"} =====');
      for (final k in list) {
        debugPrint(k);
      }
      debugPrint('===== [COUNT] ${list.length} =====');
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

  @override
  Widget build(BuildContext context) {

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: AppColors.btnColorDark,
          elevation: 0.5,
          centerTitle: true,
          leadingWidth: 0,
          // automaticallyImplyLeading: false,
          toolbarHeight: _appBarH(context),
          title: Text(
            '${widget.title} 연극',
            textScaler: const TextScaler.linear(1.0),
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
              color: Colors.white,
            ),
          ),
          // actions: [
          //   IconButton(
          //     onPressed: () => Navigator.pop(context, _savedPath != null),
          //     icon: const Icon(Icons.close),
          //     color: Colors.black87,
          //   ),
          // ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420.w),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 28.h),
            children: [
              Center(
                child: Text(
                  '${widget.lineNumber}번 대사',
                  textScaler: const TextScaler.linear(1.0),
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 28.sp,
                    color: kBlue,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // 대사 말풍선 — 탭하면 원본(에셋) 재생
              Center(
                child: GestureDetector(
                  onTap: _onTapSpeechBubblePlayAsset,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 26.w,
                      vertical: 20.h,
                    ),
                    decoration: BoxDecoration(
                      color: kBlue,
                      borderRadius: BorderRadius.circular(26.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.lineText,
                          textScaler: const TextScaler.linear(1.0),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'GmarketSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 20.sp,
                            color: kBubbleText,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isAssetPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '탭해서 원본 듣기',
                              textScaler: const TextScaler.linear(1.0),
                              style: TextStyle(
                                fontFamily: 'GmarketSans',
                                fontWeight: FontWeight.w400,
                                fontSize: 13.sp,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 28.h),

              // 큰 원형 녹음 버튼
              Center(
                child: GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 280.w,
                    height: 280.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: kBlue, width: 14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _isRecording ? '녹음\n중...' : '녹음\n시작',
                      textAlign: TextAlign.center,
                      textScaler: const TextScaler.linear(1.0),
                      style: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w500,
                        fontSize: 34.sp,
                        color: kBlue,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // 내 녹음 듣기 — 녹음 버튼 아래
              Center(
                child: SizedBox(
                  width: 260.w,
                  height: 64.h,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isMyPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: const Text(
                      '내 녹음 듣기',
                      textScaler: const TextScaler.linear(1.0),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _savedPath == null
                              ? const Color(0xFFF2F3F5)
                              : kListenYellow,
                      foregroundColor: Colors.black87,
                      disabledBackgroundColor: const Color(0xFFF2F3F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32.r),
                      ),
                      elevation: 0,
                      textStyle: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 20.sp,
                      ),
                    ),
                    onPressed: _savedPath == null ? null : _togglePlayMyRecord,
                  ),
                ),
              ),

              SizedBox(height: 28.h),

              // 하단 진행 표시
              Row(
                children: [
                  _animatedNumberBadge(
                    _sliderValue.round().clamp(1, widget.totalLines).toString(),
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

  // ====== 동작 (원본 재생 - 말풍선 탭) ======
  Future<void> _onTapSpeechBubblePlayAsset() async {
    final raw = widget.lineAssetPath?.trim();
    if (raw == null || raw.isEmpty) {
      _showSnack('원본 오디오가 없어요.');
      return;
    }

    final full = _ensureAssetFullPath(raw);
    final key = _toAssetKey(full);

    try {
      await rootBundle.load(full);

      await _myPlayer.stop();
      if (mounted) setState(() => _isMyPlaying = false);

      if (_isAssetPlaying) {
        await _assetPlayer.pause();
        if (mounted) setState(() => _isAssetPlaying = false);
        return;
      }

      await _assetPlayer.stop();
      await _assetPlayer.play(AssetSource(key));

      if (mounted) setState(() => _isAssetPlaying = true);
    } on FlutterError {
      await _debugDumpAssets(contains: p.basename(full));
      final parent = p.basename(p.dirname(full));
      if (parent.isNotEmpty) {
        await _debugDumpAssets(contains: parent);
      }
      _showSnack('원본 오디오를 찾을 수 없어요.\npubspec.yaml 또는 파일 경로(대소문자/공백)를 확인해 주세요.');
      if (mounted) setState(() => _isAssetPlaying = false);
    } catch (_) {
      _showSnack('원본 오디오를 찾을 수 없어요.');
      if (mounted) setState(() => _isAssetPlaying = false);
    }
  }

  // ====== 동작(녹음/저장) ======
  Future<void> _toggleRecording() async {
    if (_isAssetPlaying) {
      await _assetPlayer.stop();
      if (mounted) setState(() => _isAssetPlaying = false);
    }

    if (_isRecording) {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _savedPath = path;
        });
      }
      return;
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      _showSnack('마이크 권한이 필요해요.');
      return;
    }

    final dir = await getTemporaryDirectory();
    final filename =
        'story_${widget.title}_${widget.lineNumber}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = p.join(dir.path, filename);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isMyPlaying = false;
      });
    }
  }

  // ====== 동작(내 녹음 재생) ======
  Future<void> _togglePlayMyRecord() async {
    if (_savedPath == null) return;

    if (_isAssetPlaying) {
      await _assetPlayer.stop();
      if (mounted) setState(() => _isAssetPlaying = false);
    }

    if (_isMyPlaying) {
      await _myPlayer.pause();
      if (mounted) setState(() => _isMyPlaying = false);
      return;
    }
    await _myPlayer.stop();
    await _myPlayer.play(DeviceFileSource(_savedPath!));
    if (mounted) setState(() => _isMyPlaying = true);
  }

  // ====== 배지/슬라이더 UI 유틸 ======
  Widget _animatedNumberBadge(String text) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder:
          (child, anim) => ScaleTransition(scale: anim, child: child),
      child: _numberBadge(text, key: ValueKey(text), active: true),
    );
  }

  Widget _numberBadge(String text, {Key? key, bool active = false}) {
    final Color bg = active ? kBlue : const Color(0xFFDFE3EA);
    final Color fg = active ? Colors.white : kGreyNum;
    return Container(
      key: key,
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        text,
        textScaler: const TextScaler.linear(1.0),
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
