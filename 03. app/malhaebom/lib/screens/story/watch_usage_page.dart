import 'dart:io';
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

class _WatchUsagePageState extends State<WatchUsagePage> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _isNetwork = false;

  @override
  @override
  void initState() {
    super.initState();
    debugPrint('[WatchUsagePage] incoming title=${widget.title}');
    debugPrint('[WatchUsagePage] incoming videoSource=${widget.videoSource}');
    _isNetwork = widget.videoSource.startsWith('http');
    _controller =
        _isNetwork
            ? VideoPlayerController.networkUrl(Uri.parse(widget.videoSource))
            : VideoPlayerController.asset(widget.videoSource);

    _controller.addListener(() {
      final err = _controller.value.errorDescription;
      if (err != null) debugPrint('🎯 VideoPlayer errorDescription: $err');
    });

    _controller
      ..setLooping(true)
      ..initialize()
          .then((_) async {
            if (!mounted) return;
            // 🔽 자동재생 & 볼륨(원하면 조절)
            await _controller.setVolume(1.0);
            // await _controller.play();
            setState(() => _initialized = true);
          })
          .catchError((e, st) {
            debugPrint('🎯 initialize() failed: $e');
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  Future<void> _openFullscreen() async {
    if (!_initialized) return;
    final pos = await _controller.position ?? Duration.zero;
    final bool wasPlaying = _controller.value.isPlaying;
    _controller.pause();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _FullscreenVideoPage(
              source: widget.videoSource,
              isNetwork: _isNetwork,
              start: pos,
            ),
      ),
    );

    await _controller.seekTo(pos);
    if (wasPlaying) _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
            fontSize: 20.sp,
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
                  child:
                      _initialized
                          ? VideoPlayer(_controller)
                          : Container(color: const Color(0xFFE5E7EB)),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring:
                      _initialized &&
                      _controller.value.isPlaying, // 🔽 재생 중이면 터치 무시
                  child: GestureDetector(
                    onTap: _togglePlay,
                    behavior: HitTestBehavior.translucent,
                    child: AnimatedOpacity(
                      opacity:
                          !_initialized || !_controller.value.isPlaying ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Align(
                        alignment: const Alignment(0, 0.02),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 120.sp,
                          color: AppColors.btnColorDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 전체화면
              Positioned(
                right: 10.w,
                bottom: 10.w,
                child: GestureDetector(
                  onTap: _openFullscreen,
                  child: Icon(
                    Icons.crop_free,
                    size: 26.sp,
                    color: AppColors.btnColorDark,
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
              centerTitle: true, // 제목 가운데
              centerBody: false, // 목록 좌측 정렬
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
              subtitle: '동화 시청을 완료하신 분만\n화행 인지검사를 할 수 있어요.\n검사를 진행하시겠어요?',
              actions: [
                Expanded(
                  child: _ChoiceButton(
                    top: '네',
                    bottom: '검사할게요.',
                    background: _ctaYellow,
                    foreground: Colors.black,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => StoryTestinfoPage(
                                title: widget.title,
                                storyImg: widget.storyImg,
                              ),
                        ),
                      );
                    },
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
    );
  }
}

/// 리스트 아이템을 가운데로 모으고 폭 제한
class _CenteredMaxWidth extends StatelessWidget {
  const _CenteredMaxWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double maxW = 340.w.clamp(300.0, 360.0);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
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
            style: TextStyle(
              fontFamily: _kFont,
              fontWeight: FontWeight.w700,
              fontSize: 16.sp,
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
              style: TextStyle(
                fontFamily: _kFont,
                fontWeight: FontWeight.w400,
                fontSize: 13.sp,
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
              style: TextStyle(
                fontFamily: _kFont,
                fontWeight: weight,
                fontSize: 14.sp,
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
              // 상단(네/아니요) — 더 크게
              Text(
                top,
                style: TextStyle(
                  fontFamily: _kFont,
                  fontWeight: FontWeight.w800,
                  fontSize: 20.sp, // ↑ 16 → 20
                  color: foreground,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                bottom,
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _ctrl =
        widget.isNetwork
            ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
            : VideoPlayerController.asset(widget.source);

    _ctrl
      ..setLooping(true)
      ..initialize().then((_) async {
        await _ctrl.seekTo(widget.start);
        await _ctrl.play();
        if (!mounted) return;
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Positioned(
            top: 12.h,
            left: 12.w,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.translucent,
              child: AnimatedOpacity(
                opacity: !_ready || !_ctrl.value.isPlaying ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Align(
                  alignment: Alignment(0, 0.02),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 120,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
