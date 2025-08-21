import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 실제 녹음 화면(녹음/저장/재생 — DB 연결 없음)
class StoryRecordingPage extends StatefulWidget {
  final String title; // 동화 제목
  final int lineNumber; // 몇 번 대사인지(1..N)
  final int totalLines; // 총 대사 수(예: 38)
  final String lineText; // 대사 내용

  const StoryRecordingPage({
    Key? key,
    required this.title,
    required this.lineNumber,
    required this.totalLines,
    required this.lineText,
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
  final _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _savedPath; // 저장된 로컬 파일 경로 (DB 없이 메모리로만 보유)

  // --- 슬라이더 애니메이션 ---
  late final AnimationController _ctrl;
  late final Animation<double> _sliderAnim;
  late double _sliderValue;

  @override
  void initState() {
    super.initState();

    // 슬라이더: (n-1) → n 으로 살짝 이동
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

    _player.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
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
            style: TextStyle(
              fontFamily: 'GmarketSans',
              fontWeight: FontWeight.w500,
              fontSize: 20.sp,
              color: Colors.black,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context, _savedPath != null),
              icon: const Icon(Icons.close),
              color: Colors.black87,
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420.w),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 28.h),
            children: [
              // "n번 대사" (굵게)
              Center(
                child: Text(
                  '${widget.lineNumber}번 대사',
                  style: TextStyle(
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w800,
                    fontSize: 28.sp,
                    color: kBlue,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // 대사 말풍선 (보통 두께)
              Center(
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
                  child: Text(
                    widget.lineText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 20.sp,
                      color: kBubbleText,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 36.h),

              // 큰 원형 녹음 버튼 (탭: 시작/정지)
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
              SizedBox(height: 34.h),

              // 내 녹음 듣기 (저장 파일 있을 때만 활성)
              Center(
                child: SizedBox(
                  width: 260.w,
                  height: 64.h,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: const Text('내 녹음 듣기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _savedPath == null
                              ? const Color(0xFFFFE36B)
                              : kListenYellow,
                      foregroundColor: Colors.black87,
                      disabledBackgroundColor: const Color(0xFFF2F3F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32.r),
                      ),
                      elevation: 0,
                      textStyle: TextStyle(
                        fontFamily: 'GmarketSans',
                        fontWeight: FontWeight.w800, // 이 버튼만 굵게
                        fontSize: 20.sp,
                      ),
                    ),
                    onPressed: _savedPath == null ? null : _togglePlay,
                  ),
                ),
              ),

              SizedBox(height: 36.h),

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
                          onChanged: (_) {}, // 스타일 유지를 위한 더미
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

  // ====== 동작(녹음/재생) — DB 없이 파일만 저장 ======
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 정지 + 파일 경로 확보
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _savedPath = path; // 로컬 파일 경로 보관 (DB 미사용)
      });
      return;
    }

    // 권한 및 저장 경로 준비
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('마이크 권한이 필요해요.')));
      }
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

    setState(() {
      _isRecording = true;
      _isPlaying = false; // 녹음 중에는 재생 중지
    });
  }

  Future<void> _togglePlay() async {
    if (_savedPath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }
    // 새로 재생
    await _player.stop();
    await _player.play(DeviceFileSource(_savedPath!));
    setState(() => _isPlaying = true);
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
        style: TextStyle(
          fontFamily: 'GmarketSans',
          fontWeight: FontWeight.w500,
          fontSize: 18.sp,
          color: fg,
        ),
      ),
    );
  }
}
