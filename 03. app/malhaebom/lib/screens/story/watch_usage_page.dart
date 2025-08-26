// lib/screens/story/watch_usage_page.dart
import 'dart:io';
import 'dart:async';
import 'package:malhaebom/screens/story/story_testInfo_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:video_player/video_player.dart';

const _kFont = 'GmarketSans';
const _ctaYellow = Color(0xFFFACC15);

// 카드 공통 스타일
const _cardBorder = Color(0xFFF0F1F3);
const _cardShadow = BoxShadow(
  color: Color(0x14000000),
  blurRadius: 12,
  offset: Offset(0, 4),
);

class WatchUsagePage extends StatefulWidget {
  const WatchUsagePage({
    super.key,
    required this.title,
    required this.videoSource, // URL 또는 assets 경로 모두 지원
    required this.storyImg,
  });

  final String title;
  final String videoSource;
  final String storyImg;

  @override
  State<WatchUsagePage> createState() => _WatchUsagePageState();
}

class _WatchUsagePageState extends State<WatchUsagePage>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _isNetwork = false;

  // 유튜브식 컨트롤
  bool _controlsVisible = false;
  Timer? _hideTimer;
  static const _autoHideDuration = Duration(seconds: 2);

  // 다른 화면 다녀온 뒤 볼륨 복원용
  double _savedVolume = 1.0;

  void _showControls({bool autoHide = true}) {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (autoHide) {
      _hideTimer = Timer(_autoHideDuration, () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    debugPrint('[WatchUsagePage] incoming title=${widget.title}');
    debugPrint('[WatchUsagePage] incoming videoSource=${widget.videoSource}');
    _isNetwork = widget.videoSource.startsWith('http');
    _controller = _isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoSource))
        : VideoPlayerController.asset(widget.videoSource);

    _controller.addListener(() {
      final err = _controller.value.errorDescription;
      if (err != null) debugPrint('🎯 VideoPlayer errorDescription: $err');
      if (mounted) setState(() {}); // 아이콘 상태 반영
    });

    _controller
      ..setLooping(true)
      ..initialize().then((_) async {
        if (!mounted) return;
        _savedVolume = _controller.value.volume;
        await _controller.setVolume(_savedVolume);
        setState(() => _initialized = true);
        _showControls(); // 진입 시 잠깐 노출
      }).catchError((e, st) {
        debugPrint('🎯 initialize() failed: $e');
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // 앱이 백그라운드/비활성화되면 자동 멈춤
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        _initialized &&
        _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  void _togglePlay() {
    if (!_initialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
    _showControls(); // 토글 시 잠깐 보였다가 자동 숨김
  }

  Future<void> _openFullscreen() async {
    if (!_initialized) return;
    final posBefore = await _controller.position ?? Duration.zero;
    final bool wasPlaying = _controller.value.isPlaying;
    await _controller.pause(); // 중복 재생 방지

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(
          source: widget.videoSource,
          isNetwork: _isNetwork,
          start: posBefore,
        ),
      ),
    );

    if (!mounted) return;

    final Duration newPos =
        (result != null && result['pos'] is Duration)
            ? result['pos'] as Duration
            : posBefore;
    final bool playNow =
        (result != null && result['playing'] is bool)
            ? result['playing'] as bool
            : wasPlaying;

    await _controller.seekTo(newPos);
    if (playNow) {
      await _controller.play();
    } else {
      await _controller.pause();
    }
    _showControls();
  }

  // 인지검사로 이동 전 멈춤 + 볼륨 0, 복귀 시 볼륨 복원
  Future<void> _startTest() async {
    if (_initialized) {
      try {
        _savedVolume = _controller.value.volume;
        await _controller.pause();
        await _controller.setVolume(0);
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryTestinfoPage(
          title: widget.title,
          storyImg: widget.storyImg,
        ),
      ),
    );
    if (_initialized) {
      try {
        await _controller.setVolume(_savedVolume);
      } catch (_) {}
    }
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _initialized && _controller.value.isPlaying;

    // ★ 페이지 전체의 텍스트 스케일 고정
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: Colors.black87,
          centerTitle: true,
          elevation: 0,
          title: Text(
            widget.title,
            textScaler: const TextScaler.linear(1.0),
            style: TextStyle(
              fontFamily: _kFont,
              fontWeight: FontWeight.w500,
              fontSize: 28.sp,
              color: Colors.black87,
            ),
          ),
        ),
        backgroundColor: AppColors.background,
        body: ListView(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
          children: [
            // 동영상
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: AspectRatio(
                    aspectRatio:
                        _initialized ? _controller.value.aspectRatio : 16 / 9,
                    child: _initialized
                        ? VideoPlayer(_controller)
                        : Container(color: const Color(0xFFE5E7EB)),
                  ),
                ),

                // 화면 아무데나 탭 -> 컨트롤 보이기/숨기기
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () =>
                        _controlsVisible ? _hideControls() : _showControls(),
                  ),
                ),

                // 가운데 큰 재생/일시정지 토글 (컨트롤 보일 때만)
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(12.w),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 88.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // 전체화면 버튼 (컨트롤 보일 때만, 아이콘 크게 + 터치영역 확장)
                Positioned(
                  right: 10.w,
                  bottom: 10.w,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _openFullscreen,
                          child: Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Icon(
                              Icons.crop_free,
                              size: 36.sp, // ← 크게
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Q1 카드 — 제목만 가운데
            _CenteredMaxWidth(
              child: _GuideBox(
                title: 'Q. 어떻게 사용하나요?',
                centerTitle: true,
                centerBody: false,
                bullets: const [
                  _BulletItem(
                    icon: Icons.play_arrow_rounded,
                    text: '동영상을 재생해줘요.',
                    dim: false,
                  ),
                  _BulletItem(
                    icon: Icons.crop_free,
                    text: '동영상을 전체 화면으로 보여줘요.',
                    dim: true,
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Q2 카드 — 제목/본문 모두 가운데
            _CenteredMaxWidth(
              child: _GuideBox(
                title: 'Q. 동화를 모두 들으셨나요?',
                centerTitle: true,
                centerBody: true,
                subtitle:
                    '동화 시청을 완료하신 분만\n화행 인지검사를 할 수 있어요.\n검사를 진행하시겠어요?',
                actions: [
                  Expanded(
                    child: _ChoiceButton(
                      top: '네',
                      bottom: '검사할게요.',
                      background: _ctaYellow,
                      foreground: Colors.black,
                      onTap: _startTest, // ← 이동 전 멈춤/볼륨 처리
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _ChoiceButton(
                      top: '아니요',
                      bottom: '다 안 봤어요.',
                      background: const Color(0xFFE9E9EB),
                      foreground: const Color(0xFF5B5B5B),
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 리스트 아이템을 가운데로 모으되, 폭 고정 해제
class _CenteredMaxWidth extends StatelessWidget {
  const _CenteredMaxWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 부모(ListView)의 실제 가용 폭을 그대로 사용
    return LayoutBuilder(
      builder: (context, constraints) {
        final double usable = constraints.maxWidth; // ListView padding 반영된 폭
        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: usable, // 꽉 채우기
              maxWidth: usable, // 화면 크기 따라 유동
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _GuideBox extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<_BulletItem>? bullets;
  final List<Widget>? actions;
  final bool centerTitle; // 제목 가운데
  final bool centerBody; // 본문(문단) 가운데

  const _GuideBox({
    required this.title,
    this.subtitle,
    this.bullets,
    this.actions,
    this.centerTitle = false,
    this.centerBody = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _cardBorder),
        boxShadow: const [_cardShadow],
      ),
      child: Column(
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            title,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            textScaler: const TextScaler.linear(1.0), // ★ 고정
            style: TextStyle(
              fontFamily: _kFont,
              fontWeight: FontWeight.w700,
              fontSize: 23.sp,
              color: Colors.black87,
            ),
          ),

          if (bullets != null) ...[
            SizedBox(height: 10.h),
            for (final b in bullets!) _BulletRow(item: b),
          ],

          if (subtitle != null) ...[
            SizedBox(height: 10.h),
            Text(
              subtitle!,
              textAlign: centerBody ? TextAlign.center : TextAlign.start,
              textScaler: const TextScaler.linear(1.0), // ★ 고정
              style: TextStyle(
                fontFamily: _kFont,
                fontWeight: FontWeight.w400,
                fontSize: 16.sp,
                height: 1.4,
                color: const Color(0xFF6B6B6B),
              ),
            ),
          ],

          if (actions != null) ...[
            SizedBox(height: 12.h),
            Row(children: actions!),
          ],
        ],
      ),
    );
  }
}

class _BulletItem {
  final IconData icon;
  final String text;
  final bool dim;
  const _BulletItem({required this.icon, required this.text, this.dim = false});
}

class _BulletRow extends StatelessWidget {
  final _BulletItem item;
  const _BulletRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.dim ? Colors.black38 : Colors.black87;
    final weight = item.dim ? FontWeight.w400 : FontWeight.w500;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(item.icon, size: 20.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              item.text,
              textScaler: const TextScaler.linear(1.0), // ★ 고정
              style: TextStyle(
                fontFamily: _kFont,
                fontWeight: weight,
                fontSize: 16.sp,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String top;
  final String bottom;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.top,
    required this.bottom,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 버튼 내부 텍스트는 스케일 고정 + 말줄임으로 넘침 방지
    const fixedScale = TextScaler.linear(1.0);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 64.h,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                top,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: fixedScale,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 20.sp,
                  color: foreground,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                bottom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: fixedScale,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                  color: foreground.withOpacity(.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전체화면 비디오 페이지
class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.source,
    required this.isNetwork,
    this.start = Duration.zero,
  });

  final String source;
  final bool isNetwork;
  final Duration start;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  // 유튜브식 컨트롤
  bool _controlsVisible = false;
  Timer? _hideTimer;
  static const _autoHideDuration = Duration(seconds: 2);

  void _showControls({bool autoHide = true}) {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    if (autoHide) {
      _hideTimer = Timer(_autoHideDuration, () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _ctrl = widget.isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
        : VideoPlayerController.asset(widget.source);

    _ctrl
      ..setLooping(true)
      ..initialize().then((_) async {
        await _ctrl.seekTo(widget.start);
        await _ctrl.play();
        if (!mounted) return;
        setState(() => _ready = true);
        _showControls(); // 진입 시 잠깐 표시
      });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ctrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    setState(() {
      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
    });
    _showControls();
  }

  Future<void> _popWithResult() async {
    final pos = await _ctrl.position ?? Duration.zero;
    final playing = _ctrl.value.isPlaying;
    Navigator.pop(context, {'pos': pos, 'playing': playing});
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _ready && _ctrl.value.isPlaying;

    // ★ 전체화면 페이지도 텍스트 스케일 고정(미래에 텍스트 추가될 경우 대비)
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: WillPopScope(
        onWillPop: () async {
          await _popWithResult(); // 제스처/백버튼으로 나갈 때도 현재 상태 반환
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _ready ? _ctrl.value.aspectRatio : 16 / 9,
                  child: _ready ? VideoPlayer(_ctrl) : const SizedBox.shrink(),
                ),
              ),

              // 탭으로 컨트롤 표시/숨김
              Positioned.fill(
                child: GestureDetector(
                  onTap: () =>
                      _controlsVisible ? _hideControls() : _showControls(),
                  behavior: HitTestBehavior.translucent,
                ),
              ),

              // 가운데 토글 아이콘
              AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 120,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),

              // 닫기 버튼 (컨트롤 보일 때만)
              Positioned(
                top: 12.h,
                left: 12.w,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: IconButton(
                      onPressed: _popWithResult,
                      iconSize: 30,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
