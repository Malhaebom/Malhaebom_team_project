import 'package:brain_up/theme/colors.dart';
import 'package:brain_up/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PhysicalTrainingDetailPage extends StatefulWidget {
  const PhysicalTrainingDetailPage({
    super.key,
    required this.title,
    required this.data,
  });

  final String title;
  final Map<String, dynamic> data;

  @override
  State<PhysicalTrainingDetailPage> createState() =>
      _PhysicalTrainingDetailPageState();
}

class _PhysicalTrainingDetailPageState
    extends State<PhysicalTrainingDetailPage> {
  VideoPlayerController? _videoPlayerController;
  bool _showControls = true;
  bool _isEnded = false;

  @override
  void initState() {
    super.initState();
    _videoPlayerController =
        VideoPlayerController.asset(widget.data["video"])
          ..initialize().then((_) {
            setState(() {});
          })
          ..addListener(() {
            final isEnded =
                _videoPlayerController!.value.position >=
                _videoPlayerController!.value.duration;

            if (isEnded != _isEnded) {
              setState(() {
                _isEnded = isEnded;
                if (_isEnded) _showControls = true;
              });
            }
          });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
        ),
      ),
      backgroundColor: AppColors.background,
      body:
          _videoPlayerController!.value.isInitialized
              ? SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 30.w,
                    vertical: 20.h,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showControls = !_showControls;
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio:
                                  _videoPlayerController!.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController!),
                            ),

                            // 🔁 영상이 끝났을 때 → 다시보기 버튼만
                            if (_isEnded)
                              IconButton(
                                icon: Icon(
                                  Icons.replay_rounded,
                                  size: 64.h,
                                  color: Color.fromARGB(255, 150, 169, 206),
                                ),
                                onPressed: () {
                                  _videoPlayerController!.seekTo(Duration.zero);
                                  _videoPlayerController!.play();
                                  setState(() {
                                    _isEnded = false;
                                    _showControls = false;
                                  });
                                },
                              )
                            // ▶️⏸️ 재생/일시정지 버튼 (영상이 끝나지 않은 경우에만)
                            else if (_showControls)
                              IconButton(
                                icon: Icon(
                                  _videoPlayerController!.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 64.h,
                                  color: const Color.fromARGB(
                                    255,
                                    150,
                                    169,
                                    206,
                                  ),
                                ),
                                onPressed: () {
                                  if (_videoPlayerController!.value.isPlaying) {
                                    _videoPlayerController!.pause();
                                  } else {
                                    _videoPlayerController!.play();
                                  }
                                  setState(() {});
                                },
                              ),

                            // ⛶ 전체화면 버튼
                            if (!_isEnded && _showControls)
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.fullscreen,
                                    color: Color.fromARGB(255, 150, 169, 206),
                                    size: 25.h,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => FullscreenVideoPage(
                                              controller:
                                                  _videoPlayerController!,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(height: 20.h),

                      CustomSubmitButton(
                        btnText: "운동완료",
                        isActive: true,
                        onPressed: () {},
                      ),

                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 30.h),
                              Container(
                                width: 40.w,
                                height: 10.h,
                                decoration: BoxDecoration(
                                  color: AppColors.btnColorLight,
                                ),
                              ),
                              SizedBox(height: 5.h),

                              Text(
                                "어떤 운동일까요?",
                                style: TextStyle(
                                  fontFamily: 'GmarketSans',
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 5.h),
                            ],
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.data["description"],
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 40.h),
                              Container(
                                width: 40.w,
                                height: 10.h,
                                decoration: BoxDecoration(
                                  color: AppColors.btnColorLight,
                                ),
                              ),

                              SizedBox(height: 5.h),

                              Text(
                                "어떻게 사용하나요?",
                                style: TextStyle(
                                  fontFamily: 'GmarketSans',
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 5.h),
                            ],
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Icon(Icons.fullscreen, size: 23.h),
                          SizedBox(width: 4.w),
                          Text(
                            "버튼을 눌러 '전체 화면'으로 영상을 볼 수 있습니다.",
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 23.h),
                          SizedBox(width: 4),
                          Text(
                            "버튼을 눌러 영상을 '재생'할 수 있습니다.",
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Icon(Icons.pause_rounded, size: 23.h),
                          SizedBox(width: 4.w),
                          Text(
                            "버튼을 눌러 영상을 '일시중지'할 수 있습니다.",
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              : const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 150, 169, 206),
                ),
              ),
    );
  }
}

// ✅ 전체화면 페이지 (가로모드 자동, 뒤로가기 버튼 포함)
class FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;

  const FullscreenVideoPage({super.key, required this.controller});

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();

    // 가로모드 전환
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 상태바 숨김
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 세로모드 복원
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          Positioned(
            top: 32.h,
            left: 16.w,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30.h),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
