import 'package:malhaebom/data/brain_training_data.dart';
import 'package:malhaebom/screens/brain_training/brain_training_result_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/custom_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:audioplayers/audioplayers.dart';

class BrainTrainingTestPage extends StatefulWidget {
  const BrainTrainingTestPage({super.key, required this.title});

  final String title;

  @override
  State<BrainTrainingTestPage> createState() => _BrainTrainingTestPageState();
}

class _BrainTrainingTestPageState extends State<BrainTrainingTestPage> {
  Map<String, dynamic> data = {};
  double totalAnswerCnt = 0;
  double solvAnswerCnt = 0;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    loadData(widget.title);
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        title: Center(
          child: Text(
            widget.title,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20.sp),
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
                ),

              if (widget.title == "기억집중")
                ConcentrationTest(
                  data: data,
                  screenHeight: screenHeight,
                  forwardFunc: forwardFunc,
                  prevFunc: prevFunc,
                  category: widget.title,
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
                ),

              if (widget.title == "알록달록")
                ColorTest(
                  data: data,
                  screenHeight: screenHeight,
                  forwardFunc: forwardFunc,
                  prevFunc: prevFunc,
                  category: widget.title,
                ),

              if (widget.title == "음악과터치")
                MusicTest(
                  data: data,
                  screenHeight: screenHeight,
                  forwardFunc: forwardFunc,
                  prevFunc: prevFunc,
                  category: widget.title,
                ),
            ],
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
  });

  final String category;
  final Map<String, dynamic> data;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final double screenHeight;

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
  }

  void setAnswers() {
    setState(() {
      answers = List.generate(widget.data.length, (index) => -1);
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
                child: Expanded(
                  child: Text(
                    textAlign: TextAlign.center,
                    widget.data[widget.data.keys.toList()[index]]["title"],
                    style: TextStyle(
                      color: AppColors.white,
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                    ),
                    overflow: TextOverflow.visible,
                  ),
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
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: AssetImage(
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][0],
                            ),
                            fit: BoxFit.cover,
                          ),
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
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: AssetImage(
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][1],
                            ),
                            fit: BoxFit.cover,
                          ),
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
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: AssetImage(
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][2],
                            ),
                            fit: BoxFit.cover,
                          ),
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
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: AssetImage(
                              widget.data[widget.data.keys
                                  .toList()[index]]["question"][3],
                            ),
                            fit: BoxFit.cover,
                          ),
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
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Column(
            children: [
              CustomSubmitButton(
                btnText: index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                isActive: answers[index] != -1,
                onPressed: () {
                  if (index != widget.data.length - 1) {
                    if (answers[index] != -1) {
                      setState(() {
                        widget.forwardFunc();
                        index += 1;
                      });
                    }
                  } else {
                    /*
                      테스트 결과 페이지로 넘어가기
                    */
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                            ),
                      ),
                    );
                  }
                },
              ),

              SizedBox(height: 10.h),

              index != 0
                  ? CustomSubmitButton(
                    btnText: "이전 문제",
                    isActive: true,
                    onPressed: () {
                      setState(() {
                        widget.prevFunc();
                        index -= 1;
                      });
                    },
                  )
                  : Container(),

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
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;

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
  }

  void setAnswers() {
    setState(() {
      answers = List.generate(widget.data.length, (index) => -1);
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
                child: Expanded(
                  child: Text(
                    textAlign: TextAlign.center,
                    widget.data[widget.data.keys.toList()[index]]["title"],
                    style: TextStyle(
                      color: AppColors.white,
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),

              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      widget.data[widget.data.keys.toList()[index]]["question"],
                    ),
                    fit: BoxFit.fill,
                  ),
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
              SizedBox(height: 20.h),

              CustomSubmitButton(
                btnText: index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                isActive: answers[index] != -1,
                onPressed: () {
                  if (index != widget.data.length - 1) {
                    if (answers[index] != -1) {
                      setState(() {
                        widget.forwardFunc();
                        index += 1;
                      });
                    }
                  } else {
                    /*
                      테스트 결과 페이지로 넘어가기
                    */
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                            ),
                      ),
                    );
                  }
                },
              ),

              SizedBox(height: 10.h),

              index != 0
                  ? CustomSubmitButton(
                    btnText: "이전 문제",
                    isActive: true,
                    onPressed: () {
                      setState(() {
                        widget.prevFunc();
                        index -= 1;
                      });
                    },
                  )
                  : Container(),

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
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;

  @override
  State<SolvingTest> createState() => _SolvingTestState();
}

class _SolvingTestState extends State<SolvingTest> {
  int index = 0;
  List<int> answers = [];

  @override
  void initState() {
    super.initState();
    answers = List.generate(widget.data.length, (index) => -1);
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
                  style: TextStyle(
                    color: AppColors.white,
                    fontFamily: 'GmarketSans',
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(currentData["image"]),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, idx) {
                    if (idx == 4) {
                      if (index == 0) {
                        return SizedBox(height: 75.h);
                      } else {
                        return SizedBox(height: 120.h);
                      }
                    }

                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              answers[index] = idx;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(10.h),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    currentData["question"][idx],
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                      ],
                    );
                  },
                ),
              ),
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
                  CustomSubmitButton(
                    btnText:
                        index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                    isActive: answers[index] != -1,
                    onPressed: () {
                      if (answers[index] == -1) return;
                      if (index < widget.data.length - 1) {
                        setState(() {
                          widget.forwardFunc();
                          index++;
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => BrainTrainingResultPage(
                                  data: widget.data,
                                  category: widget.category,
                                ),
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 10.h),

                  if (index != 0)
                    CustomSubmitButton(
                      btnText: "이전 문제",
                      isActive: true,
                      onPressed: () {
                        setState(() {
                          widget.prevFunc();
                          index--;
                        });
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
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;

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
  }

  void setAnswers() {
    setState(() {
      answers = List.generate(
        widget.data.length,
        (index) => List.generate(
          widget.data[widget.data.keys.toList()[index]]["answer"].length,
          (index) => -1,
        ),
      );

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
                child: Expanded(
                  child: Text(
                    textAlign: TextAlign.center,
                    widget.data[widget.data.keys.toList()[index]]["title"],
                    style: TextStyle(
                      color: AppColors.white,
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      widget.data[widget.data.keys.toList()[index]]["image"],
                    ),
                    fit: BoxFit.fill,
                  ),
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

                              case 5:
                                setState(() {
                                  touchCount++;
                                  // 리스트에 2 append
                                });
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
              SizedBox(height: 20.h),

              CustomSubmitButton(
                btnText: index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
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
                    /*
                      테스트 결과 페이지로 넘어가기
                    */
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                            ),
                      ),
                    );
                  }
                },
              ),

              SizedBox(height: 10.h),

              index != 0
                  ? CustomSubmitButton(
                    btnText: "이전 문제",
                    isActive: true,
                    onPressed: () {
                      setState(() {
                        widget.prevFunc();
                        index -= 1;
                      });
                    },
                  )
                  : Container(),

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
  });

  final Map<String, dynamic> data;
  final double screenHeight;
  final VoidCallback forwardFunc;
  final VoidCallback prevFunc;
  final String category;

  @override
  State<MusicTest> createState() => _MusicTestState();
}

class _MusicTestState extends State<MusicTest> {
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
    setCount();
  }

  void setCount() {
    setState(() {
      touchCount = 0;
      totalCount = widget.data.length;
    });
  }

  bool isPlaying = false;
  void playAuido(int index) async {
    setState(() {
      isPlaying = true;
    });

    await audioPlayer.play(
      AssetSource(widget.data[widget.data.keys.toList()[index]]["sound"]),
    );
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
                            playAuido(index);
                            setState(() {
                              isPlaying = true;
                            });
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
                child: Expanded(
                  child: Text(
                    textAlign: TextAlign.center,
                    widget.data[widget.data.keys.toList()[index]]["title"],
                    style: TextStyle(
                      color: AppColors.white,
                      fontFamily: 'GmarketSans',
                      fontWeight: FontWeight.w500,
                      fontSize: 16.sp,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              Container(
                width: double.infinity,
                height: widget.screenHeight * 0.35,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      widget.data[widget.data.keys.toList()[index]]["image"],
                    ),
                    fit: BoxFit.fill,
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              InkWell(
                onTap: () {
                  setState(() {
                    touchCount += 1;
                  });
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.yellow),
                  padding: EdgeInsets.all(18.sp),
                  child: Text(
                    "터치",
                    textAlign: TextAlign.center,
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

              CustomSubmitButton(
                btnText: index != widget.data.length - 1 ? "다음 문제" : "결과 확인",
                isActive: touchCount > 0,
                onPressed: () {
                  if (index != widget.data.length - 1) {
                    if (touchCount > 0) {
                      print("왜 안멈춰");
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
                    /*
                      테스트 결과 페이지로 넘어가기
                    */
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrainTrainingResultPage(
                              data: widget.data,
                              category: widget.category,
                            ),
                      ),
                    );
                  }
                },
              ),

              SizedBox(height: 10.h),

              index != 0
                  ? CustomSubmitButton(
                    btnText: "이전 문제",
                    isActive: true,
                    onPressed: () {
                      setState(() {
                        widget.prevFunc();
                        index -= 1;
                      });
                    },
                  )
                  : Container(),

              SizedBox(height: 20.h),
            ],
          ),
        ],
      ),
    );
  }
}
