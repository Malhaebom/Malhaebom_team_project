import 'package:malhaebom/data/brain_training_data.dart';
import 'package:malhaebom/screens/brain_training/brain_training_result_page.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:audioplayers/audioplayers.dart';

class BrainTrainingTestPage extends StatefulWidget {
  const BrainTrainingTestPage({
    super.key,
    required this.title,
    this.retryIndex,
    this.retryAnswers,
  });

  final String title;
  final int? retryIndex;
  final dynamic retryAnswers;

  @override
  State<BrainTrainingTestPage> createState() => _BrainTrainingTestPageState();
}

class _BrainTrainingTestPageState extends State<BrainTrainingTestPage> {
  Map<String, dynamic> data = {};
  double totalAnswerCnt = 0;
  double solvAnswerCnt = 0;
  double progress = 0;
  List<String>? _pendingImagePaths;

  @override
  void initState() {
    super.initState();
    loadData(widget.title);
    _preloadImages();
  }

  // 이미지 프리로딩 - UI에 영향을 주지 않도록 간소화
  void _preloadImages() async {
    // 현재 카테고리의 모든 이미지 경로 수집
    List<String> imagePaths = [];

    switch (widget.title) {
      case "문제해결능력":
        imagePaths =
            BrainTrainingData.solving.values
                .map((item) => item["image"] as String)
                .toList();
        break;
      case "계산능력":
        imagePaths =
            BrainTrainingData.calculation.values
                .map((item) => item["image"] as String)
                .toList();
        break;
      case "언어능력":
        imagePaths =
            BrainTrainingData.language.values
                .map((item) => item["image"] as String)
                .toList();
        break;
    }

    // UI 렌더링에 영향을 주지 않도록 지연 처리
    if (imagePaths.isNotEmpty) {
      _pendingImagePaths = imagePaths;
    }
  }

  void loadData(String category) {
    switch (category) {
      case "시공간파악":
        setState(() {
          data = BrainTrainingData.spacetime;
          totalAnswerCnt = data.length.toDouble();
        });
        break;

      case "기억집중":
        setState(() {
          data = BrainTrainingData.concentration;
          totalAnswerCnt = data.length.toDouble();
        });
        break;

      case "문제해결능력":
        setState(() {
          data = BrainTrainingData.solving;
          totalAnswerCnt = data.length.toDouble();
        });
        break;

      case "계산능력":
        setState(() {
          data = BrainTrainingData.calculation;
          totalAnswerCnt = data.length.toDouble();
        });
        break;

      case "언어능력":
        setState(() {
          data = BrainTrainingData.language;
          totalAnswerCnt = data.length.toDouble();
        });
        break;

      case "알록달록":
        setState(() {
          data = BrainTrainingData.color;
          totalAnswerCnt = data.length.toDouble();
        });
        break;

      case "음악과터치":
        setState(() {
          data = BrainTrainingData.music;
          totalAnswerCnt = data.length.toDouble();
        });
        break;
    }
  }

  void forwardFunc() {
    setState(() {
      solvAnswerCnt += 1;
      progress = solvAnswerCnt / totalAnswerCnt;
    });
  }

  void prevFunc() {
    setState(() {
      solvAnswerCnt -= 1;
      progress = solvAnswerCnt / totalAnswerCnt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    // 프리로딩이 필요한 이미지가 있으면 처리 (UI에 영향 없이)
    if (_pendingImagePaths != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          ImagePreloader.preloadImages(_pendingImagePaths!, context);
        } catch (e) {
          print('이미지 프리로딩 오류: $e');
        } finally {
          _pendingImagePaths = null;
        }
      });
    }

    return WillPopScope(
      onWillPop: () async {
        // 재시도 모드일 때는 BrainTrainingMainPage로 이동
        if (widget.retryIndex != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => BrainTrainingMainPage()),
            (route) => false,
          );
          return false;
        }
        // 일반 모드일 때는 BrainTrainingMainPage로 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => BrainTrainingMainPage()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
          toolbarHeight: _appBarH(context),
          title: Center(
            child: Text(
              widget.title,
              textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
              style: TextStyle(fontFamily: 'GmarketSans', fontWeight: FontWeight.w700, fontSize: 20.sp, color: Colors.white),
            ),
          ),
        ),
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 15.h, horizontal: 40.w),
            child: Column(
              children: [
                LinearPercentIndicator(
                  width: screenWidth - 80.w,
                  lineHeight: 18.h,
                  percent: progress,
                  backgroundColor: const Color.fromARGB(255, 43, 63, 151),
                  progressColor: const Color.fromARGB(255, 106, 150, 231),
                  barRadius: Radius.circular(15),
                ),

                SizedBox(height: 10.h),

                if (widget.title == "시공간파악")
                  SpaceTimeTest(
                    category: widget.title,
                    data: data,
                    forwardFunc: forwardFunc,
                    prevFunc: prevFunc,
                    screenHeight: screenHeight,
                    retryIndex: widget.retryIndex,
                    retryAnswers: widget.retryAnswers,
                  ),

                if (widget.title == "기억집중")
                  ConcentrationTest(
                    data: data,
                    screenHeight: screenHeight,
                    forwardFunc: forwardFunc,
                    prevFunc: prevFunc,
                    category: widget.title,
                    retryIndex: widget.retryIndex,
                    retryAnswers: widget.retryAnswers,
                  ),

                if (widget.title == "문제해결능력" ||
                    widget.title == "계산능력" ||
                    widget.title == "언어능력")
                  SolvingTest(
                    data: data,
                    screenHeight: screenHeight,
                    forwardFunc: forwardFunc,
                    prevFunc: prevFunc,
                    category: widget.title,
                    retryIndex: widget.retryIndex,
                    retryAnswers: widget.retryAnswers,
                  ),

                if (widget.title == "알록달록")
                  ColorTest(
                    data: data,
                    screenHeight: screenHeight,
                    forwardFunc: forwardFunc,
                    prevFunc: prevFunc,
                    category: widget.title,
                    retryIndex: widget.retryIndex,
                    retryAnswers: widget.retryAnswers,
                  ),

                if (widget.title == "음악과터치")
                  MusicTest(
                    data: data,
                    screenHeight: screenHeight,
                    forwardFunc: forwardFunc,
                    prevFunc: prevFunc,
                    category: widget.title,
                    retryIndex: widget.retryIndex,
                    retryAnswers: widget.retryAnswers,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TimeDisplay extends StatefulWidget {
  const TimeDisplay({super.key});

  @override
  State<TimeDisplay> createState() => _TimeDisplayState();
}

class _TimeDisplayState extends State<TimeDisplay> {
  late StopWatchTimer stopWatchTimer;
  String displayTime = '00:00:00';

  @override
  void initState() {
    super.initState();
    stopWatchTimer = StopWatchTimer(
      mode: StopWatchMode.countUp,
      onChange: (value) {
        setState(() {
          displayTime = StopWatchTimer.getDisplayTime(
            value,
            milliSecond: false,
          );
        });
      },
    );
    stopWatchTimer.onStartTimer();
  }

  @override
  void dispose() async {
    super.dispose();
    await stopWatchTimer.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      displayTime,
      textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16.sp),
    );
  }
}

/* 

  시공간파악

*/
class SpaceTimeTest extends StatefulWidget {
  const SpaceTimeTest({
    super.key,
    required this.category,
    required this.data,
    required this.forwardFunc,
    required this.prevFunc,
    required this.screenHeight,
    this.retryIndex,
    this.retryAnswers,
  });

  final String category;
  final Map<String, dynamic> data;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final double screenHeight;
  final int? retryIndex;
  final dynamic retryAnswers;

  @override
  State<SpaceTimeTest> createState() => _SpaceTimeTestState();
}

class _SpaceTimeTestState extends State<SpaceTimeTest> {
  int index = 0;
  List<int> answers = [];

  @override
  void initState() {
    super.initState();
    setAnswers();
    // 재시도인 경우 해당 문제로 이동
    if (widget.retryIndex != null) {
      index = widget.retryIndex!;
    }
  }

  void setAnswers() {
    setState(() {
      if (widget.retryAnswers != null && widget.retryAnswers is List<int>) {
        // 재시도인 경우 기존 답변 복원
        answers = List<int>.from(widget.retryAnswers);
      } else {
        answers = List.generate(widget.data.length, (index) => -1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.data.keys.toList()[index],
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  TimeDisplay(),
                ],
              ),
              SizedBox(height: 5.h),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  textAlign: TextAlign.center,
                  widget.data[widget.data.keys.toList()[index]]["title"],
                  textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  style: TextStyle(
                    color: AppColors.white,
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),

              SizedBox(height: 10.h),

              Row(
                children: [
                  // 1번
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          answers[index] = 0;
                        });
                      },
                      child: Container(
                        height: widget.screenHeight * 0.2,
                        decoration: BoxDecoration(
                          boxShadow:
                              answers[index] == 0
                                  ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: OptimizedImage(
                          imagePath:
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][0],
                          height: widget.screenHeight * 0.2,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 8.h),

                  // 2번
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          answers[index] = 1;
                        });
                      },
                      child: Container(
                        height: widget.screenHeight * 0.2,
                        decoration: BoxDecoration(
                          boxShadow:
                              answers[index] == 1
                                  ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: OptimizedImage(
                          imagePath:
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][1],
                          height: widget.screenHeight * 0.2,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8.h),

              Row(
                children: [
                  // 3번
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          answers[index] = 2;
                        });
                      },
                      child: Container(
                        height: widget.screenHeight * 0.2,
                        decoration: BoxDecoration(
                          boxShadow:
                              answers[index] == 2
                                  ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: OptimizedImage(
                          imagePath:
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][2],
                          height: widget.screenHeight * 0.2,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 8.h),

                  // 4번
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          answers[index] = 3;
                        });
                      },
                      child: Container(
                        height: widget.screenHeight * 0.2,
                        decoration: BoxDecoration(
                          boxShadow:
                              answers[index] == 3
                                  ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: OptimizedImage(
                          imagePath:
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][3],
                          height: widget.screenHeight * 0.2,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Column(
            children: [
              // 재시도 모드가 아닐 때만 버튼들 표시
              if (widget.retryIndex == null)
                Row(
                  children: [
                    Expanded(
                      child: CustomSubmitButton(
                        btnText: "이전 문제",
                        isActive: index != 0,
                        onPressed:
                            index != 0
                                ? () {
                                  setState(() {
                                    widget.prevFunc();
                                    index -= 1;
                                  });
                                }
                                : () {},
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: CustomSubmitButton(
                        btnText:
                            index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                        isActive: answers[index] != -1,
                        onPressed: () {
                          if (answers[index] == -1) return;
                          if (index != widget.data.length - 1) {
                            setState(() {
                              widget.forwardFunc();
                              index += 1;
                            });
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => BrainTrainingResultPage(
                                      data: widget.data,
                                      category: widget.category,
                                      answers: answers,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

              // 재시도 모드일 때만 결과 확인 버튼 표시
              if (widget.retryIndex != null)
                CustomSubmitButton(
                  btnText: "결과 확인",
                  isActive: answers[index] != -1,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                              answers: answers,
                              originalAnswers: widget.retryAnswers, // 기존 답변 전달
                            ),
                      ),
                    );
                  },
                ),

              SizedBox(height: 20.h),
            ],
          ),
        ],
      ),
    );
  }
}

/* 

  기억집중

*/
class ConcentrationTest extends StatefulWidget {
  const ConcentrationTest({
    super.key,
    required this.data,
    required this.screenHeight,
    required this.forwardFunc,
    required this.prevFunc,
    required this.category,
    this.retryIndex,
    this.retryAnswers,
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;
  final int? retryIndex;
  final dynamic retryAnswers;

  @override
  State<ConcentrationTest> createState() => _ConcentrationTestState();
}

class _ConcentrationTestState extends State<ConcentrationTest> {
  int index = 0;
  List<int> answers = [];

  @override
  void initState() {
    super.initState();
    setAnswers();
    // 재시도인 경우 해당 문제로 이동
    if (widget.retryIndex != null) {
      index = widget.retryIndex!;
    }
  }

  void setAnswers() {
    setState(() {
      if (widget.retryAnswers != null && widget.retryAnswers is List<int>) {
        // 재시도인 경우 기존 답변 복원
        answers = List<int>.from(widget.retryAnswers);
      } else {
        answers = List.generate(widget.data.length, (index) => -1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.data.keys.toList()[index],
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  TimeDisplay(),
                ],
              ),
              SizedBox(height: 5.h),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  textAlign: TextAlign.center,
                  widget.data[widget.data.keys.toList()[index]]["title"],
                  textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  style: TextStyle(
                    color: AppColors.white,
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),

              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                child: OptimizedImage(
                  imagePath:
                      widget.data[widget.data.keys.toList()[index]]["question"],
                  width: double.infinity,
                  height: widget.screenHeight * 0.35,
                  fit: BoxFit.fill,
                ),
              ),

              SizedBox(height: 10.h),

              Row(
                children: [
                  Expanded(
                    // O
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          answers[index] = 0;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(15.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.yellow,
                          boxShadow:
                              answers[index] == 0
                                  ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Image.asset(
                          "assets/images/o.png",
                          color: AppColors.white,
                          height: 40.h,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 10.w),

                  // X
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          answers[index] = 1;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(15.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.red,
                          boxShadow:
                              answers[index] == 1
                                  ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(100, 0, 0, 0),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Image.asset(
                          "assets/images/x.png",
                          color: AppColors.white,
                          height: 40.h,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Column(
            children: [
              // 재시도 모드가 아닐 때만 버튼들 표시
              if (widget.retryIndex == null)
                Row(
                  children: [
                    Expanded(
                      child: CustomSubmitButton(
                        btnText: "이전 문제",
                        isActive: index != 0,
                        onPressed:
                            index != 0
                                ? () {
                                  setState(() {
                                    widget.prevFunc();
                                    index -= 1;
                                  });
                                }
                                : () {},
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: CustomSubmitButton(
                        btnText:
                            index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                        isActive: answers[index] != -1,
                        onPressed: () {
                          if (answers[index] == -1) return;
                          if (index != widget.data.length - 1) {
                            setState(() {
                              widget.forwardFunc();
                              index += 1;
                            });
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => BrainTrainingResultPage(
                                      data: widget.data,
                                      category: widget.category,
                                      answers: answers,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

              // 재시도 모드일 때만 결과 확인 버튼 표시
              if (widget.retryIndex != null)
                CustomSubmitButton(
                  btnText: "결과 확인",
                  isActive: answers[index] != -1,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                              answers: answers,
                              originalAnswers: widget.retryAnswers, // 기존 답변 전달
                            ),
                      ),
                    );
                  },
                ),

              SizedBox(height: 20.h),
            ],
          ),
        ],
      ),
    );
  }
}

/* 

  문제해결능력(+ 계산능력, 언어능력)

*/
class SolvingTest extends StatefulWidget {
  const SolvingTest({
    super.key,
    required this.data,
    required this.screenHeight,
    required this.forwardFunc,
    required this.prevFunc,
    required this.category,
    this.retryIndex,
    this.retryAnswers,
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;
  final int? retryIndex;
  final dynamic retryAnswers;

  @override
  State<SolvingTest> createState() => _SolvingTestState();
}

class _SolvingTestState extends State<SolvingTest> {
  int index = 0;
  List<int> answers = [];

  @override
  void initState() {
    super.initState();
    if (widget.retryAnswers != null && widget.retryAnswers is List<int>) {
      // 재시도인 경우 기존 답변 복원
      answers = List<int>.from(widget.retryAnswers);
    } else {
      answers = List.generate(widget.data.length, (index) => -1);
    }
    // 재시도인 경우 해당 문제로 이동
    if (widget.retryIndex != null) {
      index = widget.retryIndex!;
    }
  }

  Widget _buildAnswerOptions() {
    final currentKey = widget.data.keys.toList()[index];
    final currentData = widget.data[currentKey];
    final questionCount = currentData["question"].length;

    // 디버깅용 로그 추가
    print(
      "Category: ${widget.category}, CurrentKey: $currentKey, QuestionCount: $questionCount",
    );

    // 문제해결능력의 문제01, 02만 세로형(1x4)으로 표시
    if (widget.category == "문제해결능력" &&
        (currentKey == "문제01" || currentKey == "문제02")) {
      // 세로형 리스트로 표시
      return ListView.builder(
        itemCount: questionCount + 1, // 하단 여백을 위한 +1
        itemBuilder: (context, idx) {
          if (idx == questionCount) {
            // 하단 여백
            return SizedBox(height: 12.h); // 15.h에서 12.h로 줄임
          }
          return Column(
            children: [
              _buildAnswerOption(idx),
              SizedBox(height: 4.h), // 6.h에서 4.h로 더 줄임
            ],
          );
        },
      );
    } else if (questionCount == 4) {
      // 그 외의 4개 선택지는 모두 2x2 그리드로 표시
      return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        padding: EdgeInsets.only(bottom: 20.h),
        children: List.generate(
          questionCount,
          (idx) => _buildAnswerOption(idx),
        ),
      );
    } else {
      // 그 외의 경우는 기존 리스트 형태로 표시
      return ListView.builder(
        itemCount: questionCount + 1, // 하단 여백을 위한 +1
        itemBuilder: (context, idx) {
          if (idx == questionCount) {
            // 하단 여백
            return SizedBox(height: 20.h);
          }
          return Column(
            children: [_buildAnswerOption(idx), SizedBox(height: 8.h)],
          );
        },
      );
    }
  }

  Widget _buildAnswerOption(int idx) {
    final currentKey = widget.data.keys.toList()[index];
    final currentData = widget.data[currentKey];

    // 문제해결능력의 문제01, 02는 선택지 박스 가로길이 조정
    bool isProblemSolving01or02 =
        widget.category == "문제해결능력" &&
        (currentKey == "문제01" || currentKey == "문제02");

    return InkWell(
      onTap: () {
        setState(() {
          answers[index] = idx;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width:
            isProblemSolving01or02
                ? double.infinity
                : null, // 문제01, 02는 전체 너비 사용
        height: 44, // 48에서 44로 더 줄여서 공간 확보
        padding: EdgeInsets.symmetric(
          vertical: 8.h, // 10.h에서 8.h로 더 줄임
          horizontal: isProblemSolving01or02 ? 20.w : 12.w, // 문제01, 02는 더 넓은 패딩
        ),
        decoration: BoxDecoration(
          color: answers[index] == idx ? AppColors.yellow : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              answers[index] == idx
                  ? Border.all(color: AppColors.yellow, width: 2)
                  : Border.all(color: Colors.grey.shade300),
          boxShadow:
              answers[index] == idx
                  ? [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                  : [],
        ),
        child: Center(
          child: Text(
            currentData["question"][idx],
            textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
            style: TextStyle(
              fontSize: 15.sp, // 모든 문제에서 동일한 폰트 크기 사용
              fontWeight: FontWeight.w500,
              color: answers[index] == idx ? AppColors.text : AppColors.text,
            ),
            textAlign: TextAlign.center,
            maxLines: 3, // 모든 문제에서 동일한 줄 수 허용
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = widget.data.keys.toList()[index];
    final currentData = widget.data[currentKey];

    return Expanded(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentKey,
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  TimeDisplay(),
                ],
              ),
              SizedBox(height: 5.h),
              Container(
                padding: EdgeInsets.all(15),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  currentData["title"],
                  textAlign: TextAlign.center,
                  textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  style: TextStyle(
                    color: AppColors.white,
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              // 이미지 표시 - 반응형 높이 설정으로 선택지 공간 확보
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight:
                      currentKey == "문제03"
                          ? widget.screenHeight *
                              0.35 // 문제03은 높이 감소
                          : widget.screenHeight * 0.30, // 일반 문제도 높이 감소
                ),
                child: OptimizedImage(
                  imagePath: currentData["image"],
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(child: _buildAnswerOptions()),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(color: AppColors.background),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 15.h),
                  // 재시도 모드가 아닐 때만 버튼들 표시
                  if (widget.retryIndex == null)
                    Row(
                      children: [
                        Expanded(
                          child: CustomSubmitButton(
                            btnText: "이전 문제",
                            isActive: index != 0,
                            onPressed:
                                index != 0
                                    ? () {
                                      setState(() {
                                        widget.prevFunc();
                                        index--;
                                      });
                                    }
                                    : () {},
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: CustomSubmitButton(
                            btnText:
                                index != widget.data.length - 1
                                    ? "다음 문제"
                                    : "결과 확인",
                            isActive: answers[index] != -1,
                            onPressed: () {
                              if (answers[index] == -1) return;
                              if (index < widget.data.length - 1) {
                                setState(() {
                                  widget.forwardFunc();
                                  index++;
                                });
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => BrainTrainingResultPage(
                                          data: widget.data,
                                          category: widget.category,
                                          answers: answers,
                                        ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                  // 재시도 모드일 때만 결과 확인 버튼 표시
                  if (widget.retryIndex != null)
                    CustomSubmitButton(
                      btnText: "결과 확인",
                      isActive: answers[index] != -1,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => BrainTrainingResultPage(
                                  data: widget.data,
                                  category: widget.category,
                                  answers: answers,
                                  originalAnswers:
                                      widget.retryAnswers, // 기존 답변 전달
                                ),
                          ),
                        );
                      },
                    ),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* 

  알록달록

*/
class ColorTest extends StatefulWidget {
  const ColorTest({
    super.key,
    required this.data,
    required this.screenHeight,
    required this.forwardFunc,
    required this.prevFunc,
    required this.category,
    this.retryIndex,
    this.retryAnswers,
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;
  final int? retryIndex;
  final dynamic retryAnswers;

  @override
  State<ColorTest> createState() => _ColorTestState();
}

class _ColorTestState extends State<ColorTest> {
  int index = 0;
  List<List> answers = [];

  int touchCount = 0;
  int totalCount = 0;

  bool isTapDownLeft = false;
  bool isTapDownRight = false;

  int questionCnt = 0;

  @override
  void initState() {
    super.initState();
    setAnswers();
    setCount();
    // 재시도인 경우 해당 문제로 이동
    if (widget.retryIndex != null) {
      index = widget.retryIndex!;
    }
  }

  void setAnswers() {
    setState(() {
      if (widget.retryAnswers != null && widget.retryAnswers is List<List>) {
        // 재시도인 경우 기존 답변 복원
        answers = List<List>.from(widget.retryAnswers);
      } else {
        answers = List.generate(
          widget.data.length,
          (index) => List.generate(
            widget.data[widget.data.keys.toList()[index]]["answer"].length,
            (innerIndex) => -1,
          ),
        );
      }

      questionCnt =
          widget.data[widget.data.keys.toList()[index]]["question"].length;
    });
  }

  void setCount() {
    setState(() {
      touchCount = 0;
      totalCount =
          widget.data[widget.data.keys.toList()[index]]["answer"].length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.data.keys.toList()[index],
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                    style: TextStyle(
                      fontFamily: 'GmarketSans',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  TimeDisplay(),
                ],
              ),
              SizedBox(height: 5.h),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  textAlign: TextAlign.center,
                  widget.data[widget.data.keys.toList()[index]]["title"],
                  textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  style: TextStyle(
                    color: AppColors.white,
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),

              SizedBox(height: 10.h),

              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                child: OptimizedImage(
                  imagePath:
                      widget.data[widget.data.keys.toList()[index]]["image"],
                  width: double.infinity,
                  height: widget.screenHeight * 0.35,
                  fit: BoxFit.fill,
                ),
              ),

              SizedBox(height: 10.h),

              Row(
                children: [
                  Expanded(
                    // 왼쪽
                    child: InkWell(
                      onDoubleTap: () {
                        setState(() {
                          isTapDownLeft = true;
                        });

                        if (questionCnt == 4 || questionCnt == 5) {
                          setState(() {
                            touchCount++;
                            // 리스트에 1 append
                          });
                        }

                        setState(() {
                          isTapDownLeft = false;
                        });
                      },
                      onTapDown: (details) {
                        if (totalCount > touchCount) {
                          setState(() {
                            isTapDownLeft = true;
                          });
                          if (!isTapDownRight) {
                            setState(() {
                              touchCount++;
                              // 리스트에 0 append
                            });
                          } else {
                            switch (questionCnt) {
                              case 2:
                                break;

                              case 3:
                                setState(() {
                                  touchCount++;
                                  // 리스트에 1 append
                                });
                                break;

                              case 5:
                                setState(() {
                                  touchCount++;
                                  // 리스트에 2 append
                                });
                                break;
                            }
                          }
                        }
                      },
                      onTapUp: (details) {
                        setState(() {
                          isTapDownLeft = false;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(18.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Color(
                            int.parse(
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][0],
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "왼쪽",
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              color: AppColors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 10.w),

                  // 오른쪽
                  Expanded(
                    child: InkWell(
                      onDoubleTap: () {
                        setState(() {
                          isTapDownRight = true;
                        });

                        if (questionCnt == 4) {
                          setState(() {
                            touchCount++;
                            // 리스트에 2 append
                          });
                        } else if (questionCnt == 5) {
                          setState(() {
                            touchCount++;
                            // 리스트에 3 append
                          });
                        }

                        setState(() {
                          isTapDownRight = false;
                        });
                      },
                      onTapDown: (details) {
                        if (totalCount > touchCount) {
                          setState(() {
                            isTapDownRight = true;
                          });
                          if (!isTapDownLeft) {
                            setState(() {
                              touchCount++;
                            });
                          }
                        }
                      },
                      onTapUp: (details) {
                        setState(() {
                          isTapDownRight = false;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(18.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Color(
                            int.parse(
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][1],
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "오른쪽",
                            style: TextStyle(
                              fontFamily: 'GmarketSans',
                              color: AppColors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 25.h),
              Text(
                "$touchCount/$totalCount",
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16.sp,
                  fontFamily: 'GmarketSans',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          Column(
            children: [
              // 재시도 모드가 아닐 때만 버튼들 표시
              if (widget.retryIndex == null)
                Row(
                  children: [
                    Expanded(
                      child: CustomSubmitButton(
                        btnText: "이전 문제",
                        isActive: index != 0,
                        onPressed:
                            index != 0
                                ? () {
                                  setState(() {
                                    widget.prevFunc();
                                    index -= 1;
                                  });
                                }
                                : () {},
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: CustomSubmitButton(
                        btnText:
                            index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                        isActive: totalCount == touchCount,
                        onPressed: () {
                          if (index != widget.data.length - 1) {
                            if (totalCount == touchCount) {
                              setState(() {
                                widget.forwardFunc();
                                index += 1;
                              });
                              setCount();
                            }
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => BrainTrainingResultPage(
                                      data: widget.data,
                                      category: widget.category,
                                      answers: answers,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

              // 재시도 모드일 때만 결과 확인 버튼 표시
              if (widget.retryIndex != null)
                CustomSubmitButton(
                  btnText: "결과 확인",
                  isActive: totalCount == touchCount,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                              answers: answers,
                              originalAnswers: widget.retryAnswers, // 기존 답변 전달
                            ),
                      ),
                    );
                  },
                ),

              SizedBox(height: 20.h),
            ],
          ),
        ],
      ),
    );
  }
}

/* 

  음악과 터치

*/
class MusicTest extends StatefulWidget {
  const MusicTest({
    super.key,
    required this.data,
    required this.screenHeight,
    required this.forwardFunc,
    required this.prevFunc,
    required this.category,
    this.retryIndex,
    this.retryAnswers,
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;
  final int? retryIndex;
  final dynamic retryAnswers;

  @override
  State<MusicTest> createState() => _MusicTestState();
}

class _MusicTestState extends State<MusicTest> with WidgetsBindingObserver {
  int index = 0;
  List<List> answers = [];

  int touchCount = 0;
  int totalCount = 0;

  bool isTapDownLeft = false;
  bool isTapDownRight = false;

  int questionCnt = 0;

  AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setAnswers();
    setCount();
    // 재시도인 경우 해당 문제로 이동
    if (widget.retryIndex != null) {
      index = widget.retryIndex!;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    audioPlayer.stop();
    audioPlayer.dispose();
    super.dispose();
  }

  // 앱 라이프사이클 감지: 홈버튼 누를 때 자동 재생 중지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // 홈버튼이나 다른 앱으로 이동할 때 음악 자동 중지
      if (isPlaying) {
        audioPlayer.stop();
        setState(() {
          isPlaying = false;
        });
      }
    }
  }

  void setAnswers() {
    setState(() {
      if (widget.retryAnswers != null && widget.retryAnswers is List<List>) {
        // 재시도인 경우 기존 답변 복원
        answers = List<List>.from(widget.retryAnswers);
      } else {
        // 음악과터치는 answer가 단일 정수값이므로 단일 값으로 초기화
        answers = List.generate(
          widget.data.length,
          (index) => [-1], // 단일 값으로 초기화
        );
      }
    });
  }

  void setCount() {
    setState(() {
      touchCount = 0;
      totalCount = widget.data.length;
    });
  }

  bool isPlaying = false;
  void playAudio(int index) async {
    try {
      setState(() {
        isPlaying = true;
      });

      await audioPlayer.play(
        AssetSource(widget.data[widget.data.keys.toList()[index]]["sound"]),
      );

      // 재생 완료 시 상태 업데이트
      audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          isPlaying = false;
        });
      });
    } catch (e) {
      print('음악 재생 오류: $e');
      setState(() {
        isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.data.keys.toList()[index],
                        textScaler: const TextScaler.linear(
                          1.0,
                        ), // 시스템 폰트 크기 설정 무시
                        style: TextStyle(
                          fontFamily: 'GmarketSans',
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      InkWell(
                        onTap: () {
                          if (isPlaying) {
                            audioPlayer.stop();
                            setState(() {
                              isPlaying = false;
                            });
                          } else {
                            playAudio(index);
                          }
                        },
                        child: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 35.sp,
                          color: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  TimeDisplay(),
                ],
              ),
              SizedBox(height: 5.h),
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  textAlign: TextAlign.center,
                  widget.data[widget.data.keys.toList()[index]]["title"],
                  textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  style: TextStyle(
                    color: AppColors.white,
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),

              SizedBox(height: 10.h),

              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                child: OptimizedImage(
                  imagePath:
                      widget.data[widget.data.keys.toList()[index]]["image"],
                  width: double.infinity,
                  height: widget.screenHeight * 0.35,
                  fit: BoxFit.fill,
                ),
              ),

              SizedBox(height: 10.h),

              InkWell(
                onTap: () {
                  setState(() {
                    touchCount += 1;
                    // 답변 저장
                    answers[index][0] = touchCount;
                  });
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.yellow),
                  padding: EdgeInsets.all(18.sp),
                  child: Text(
                    "터치",
                    textAlign: TextAlign.center,
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                    style: TextStyle(
                      fontFamily: 'Gmarketsans',
                      fontSize: 18.sp,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 25.h),
              Text(
                "$touchCount번 터치",
                textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16.sp,
                  fontFamily: 'GmarketSans',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          Column(
            children: [
              SizedBox(height: 20.h),

              // 재시도 모드가 아닐 때만 버튼들 표시
              if (widget.retryIndex == null)
                Row(
                  children: [
                    Expanded(
                      child: CustomSubmitButton(
                        btnText: "이전 문제",
                        isActive: index != 0,
                        onPressed:
                            index != 0
                                ? () {
                                  setState(() {
                                    widget.prevFunc();
                                    index -= 1;
                                  });
                                }
                                : () {},
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: CustomSubmitButton(
                        btnText:
                            index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                        isActive: touchCount > 0,
                        onPressed: () {
                          if (index != widget.data.length - 1) {
                            if (touchCount > 0) {
                              // 현재 문제의 답변 저장
                              answers[index][0] = touchCount;
                              setState(() {
                                widget.forwardFunc();
                                index += 1;
                                isPlaying = false;
                                audioPlayer.stop();
                                audioPlayer.release();
                              });
                              setCount();
                            }
                          } else {
                            setState(() {
                              isPlaying = false;
                              audioPlayer.stop();
                              audioPlayer.release();
                            });
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => BrainTrainingResultPage(
                                      data: widget.data,
                                      category: widget.category,
                                      answers: answers,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

              // 재시도 모드일 때만 결과 확인 버튼 표시
              if (widget.retryIndex != null)
                CustomSubmitButton(
                  btnText: "결과 확인",
                  isActive: touchCount > 0,
                  onPressed: () {
                    // 현재 문제의 답변 저장
                    answers[index][0] = touchCount;
                    setState(() {
                      isPlaying = false;
                      audioPlayer.stop();
                      audioPlayer.release();
                    });
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                              answers: answers,
                              originalAnswers: widget.retryAnswers, // 기존 답변 전달
                            ),
                      ),
                    );
                  },
                ),

              SizedBox(height: 20.h),
            ],
          ),
        ],
      ),
    );
  }
}

// 이미지 프리로딩 및 캐싱 최적화
class ImagePreloader {
  static final Map<String, bool> _preloadedImages = {};

  // 이미지 프리로딩 (BuildContext 필요)
  static Future<void> preloadImage(
    String imagePath,
    BuildContext context,
  ) async {
    if (_preloadedImages.containsKey(imagePath)) return;

    try {
      await precacheImage(AssetImage(imagePath), context);
      _preloadedImages[imagePath] = true;
    } catch (e) {
      print('이미지 프리로딩 실패: $imagePath - $e');
    }
  }

  // 여러 이미지 일괄 프리로딩 (BuildContext 필요)
  static Future<void> preloadImages(
    List<String> imagePaths,
    BuildContext context,
  ) async {
    await Future.wait(imagePaths.map((path) => preloadImage(path, context)));
  }

  // 이미지가 프리로드되었는지 확인
  static bool isPreloaded(String imagePath) {
    return _preloadedImages.containsKey(imagePath);
  }
}

// 고성능 이미지 위젯 - 렌더링 최적화
class OptimizedImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const OptimizedImage({
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(10),
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        // 렌더링 최적화를 위한 캐시 크기 설정
        cacheWidth: _calculateCacheWidth(),
        cacheHeight: _calculateCacheHeight(),
        // 빠른 로딩을 위한 최적화
        gaplessPlayback: true, // 이미지 전환 시 깜빡임 방지
        // 간소화된 로딩 상태 처리
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 150), // 더 빠른 페이드인
            curve: Curves.easeOut,
            child: child,
          );
        },
        // 에러 처리
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey[600],
                size: 30.sp,
              ),
            ),
          );
        },
      ),
    );
  }

  // 최적화된 캐시 크기 계산
  int? _calculateCacheWidth() {
    // BoxFit.contain인 경우 비율 유지를 위해 캐시 크기 제한 해제
    if (fit == BoxFit.contain) {
      return null; // 비율 유지를 위해 캐시 크기 제한 해제
    }
    // 기타 경우에는 적절한 크기로 제한
    return 800; // 일관된 크기로 메모리 효율성 향상
  }

  int? _calculateCacheHeight() {
    // BoxFit.contain인 경우 비율 유지를 위해 캐시 크기 제한 해제
    if (fit == BoxFit.contain) {
      return null; // 비율 유지를 위해 캐시 크기 제한 해제
    }
    // 기타 경우에는 적절한 크기로 제한
    return 600; // 일관된 크기로 메모리 효율성 향상
  }
}
