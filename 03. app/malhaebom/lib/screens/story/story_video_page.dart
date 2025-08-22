import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class StoryVideoPage extends StatefulWidget {
  const StoryVideoPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  /// 제목별 동영상 경로 매핑
  static const Map<String, String> storyVideoMap = {
    '어머니의 벙어리 장갑': 'assets/fairytale/어머니의벙어리장갑.mp4',
    '아버지와 결혼식': 'assets/fairytale/아버지와결혼식.mp4',
    '아들의 호빵': 'assets/fairytale/아들의 호빵.mp4',
    '할머니와 바나나': 'assets/fairytale/할머니와바나나.mp4',
  };

  /// 제목만으로 생성할 때 사용하는 팩토리
  factory StoryVideoPage.fromTitle({Key? key, required String title}) {
    final path = storyVideoMap[title];
    return StoryVideoPage(
      key: key,
      title: title,
      assetPath: path ?? 'assets/fairytale/어머니의벙어리장갑.mp4',
    );
  }

  final String title;
  final String assetPath;

  @override
  State<StoryVideoPage> createState() => _StoryVideoPageState();
}

class _StoryVideoPageState extends State<StoryVideoPage> {
  late VideoPlayerController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        if (mounted) setState(() => _loading = false);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoryVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      // 소스가 바뀌면 컨트롤러를 재생성
      final wasPlaying = _controller.value.isPlaying;
      _controller.dispose();
      _loading = true;
      setState(() {});
      final newController = VideoPlayerController.asset(widget.assetPath);
      newController.initialize().then((_) {
        if (!mounted) return;
        if (wasPlaying) newController.play();
        setState(() {
          _loading = false;
        });
      });
      _controller = newController;
    }
  }

  void _togglePlay() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  void _goFullscreen() async {
    if (!_controller.value.isInitialized) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(controller: _controller),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isInit = _controller.value.isInitialized;
    final aspect =
        isInit && _controller.value.aspectRatio > 0
            ? _controller.value.aspectRatio
            : 16 / 9;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // === ClipRect + Align 패치 ===
                ClipRect(
                  child: Align(
                    alignment: Alignment.center,
                    widthFactor: 0.999, // 우측 1px 라인 잘라내기
                    child:
                        isInit
                            ? VideoPlayer(_controller)
                            : const SizedBox.shrink(),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _Controls(
                    isInitialized: isInit,
                    isPlaying: _controller.value.isPlaying,
                    onPlayPause: _togglePlay,
                    onFullscreen: _goFullscreen,
                    loading: _loading,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _QuestionCard(
            title: '어떻게 사용하나요?',
            lines: const ['동영상을 재생해줘요.', '동영상을 전체 화면으로 보여줘요.'],
          ),
          const SizedBox(height: 12),
          _QuestionCard(
            title: '동화를 모두 들으셨나요?',
            lines: const ['동화 시청을 완료하시면', '화행 인지검사를 볼 수 있어요.', '검사를 진행하시겠어요?'],
            actions: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                ),
                child: const Text('네 검사할게요.'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                ),
                child: const Text('아니요 다 안 봤어요.'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FullscreenVideoPage extends StatelessWidget {
  const _FullscreenVideoPage({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final isInit = controller.value.isInitialized;
    final aspect =
        isInit && controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: 0.999, // 전체화면에서도 동일하게 잘라내기
                child:
                    isInit ? VideoPlayer(controller) : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isInitialized,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onFullscreen,
    required this.loading,
  });

  final bool isInitialized;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isInitialized || loading,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isInitialized || loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                onPressed: onPlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onFullscreen,
              icon: const Icon(Icons.fullscreen, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.title, required this.lines, this.actions});

  final String title;
  final List<String> lines;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.play_arrow, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actions != null) ...[
            const SizedBox(height: 8),
            Row(children: actions!),
          ],
        ],
      ),
    );
  }
}


