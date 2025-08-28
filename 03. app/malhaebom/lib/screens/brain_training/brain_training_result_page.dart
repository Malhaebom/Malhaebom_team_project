import 'package:malhaebom/screens/main/home_page.dart';
import 'package:malhaebom/screens/brain_training/brain_training_start_page.dart';
import 'package:malhaebom/screens/brain_training/brain_training_main_page.dart';
import 'package:malhaebom/theme/colors.dart';
import 'package:malhaebom/widgets/liquid_circle_progress_widget.dart';
import 'package:malhaebom/screens/brain_training/brain_training_test_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BrainTrainingResultPage extends StatefulWidget {
  const BrainTrainingResultPage({
    super.key,
    required this.category,
    required this.data,
    required this.answers,
    this.originalAnswers, // 기존 답변 추가
  });

  final String category;
  final Map<String, dynamic> data;
  final dynamic answers;
  final dynamic originalAnswers; // 기존 답변

  @override
  State<BrainTrainingResultPage> createState() =>
      _BrainTrainingResultPageState();
}

class _BrainTrainingResultPageState extends State<BrainTrainingResultPage> {
  late int correctAnswers;
  late double correctPercentage;
  late int originalCorrectAnswers; // 기존 정답 수
  late double originalCorrectPercentage; // 기존 정답률

  @override
  void initState() {
    super.initState();
    calculateResults();
  }

  void calculateResults() {
    correctAnswers = 0;
    originalCorrectAnswers = 0;
    final keys = widget.data.keys.toList();

    // answers 타입에 따른 처리
    if (widget.answers is List<int>) {
      // 단순 선택형 문제들 (시공간파악, 기억집중, 문제해결능력, 계산능력, 언어능력)
      List<int> simpleAnswers = widget.answers as List<int>;

      for (int i = 0; i < simpleAnswers.length; i++) {
        if (i < keys.length) {
          final userAnswer = simpleAnswers[i];
          final correctAnswer = widget.data[keys[i]]["answer"];

          bool isCorrect = userAnswer == correctAnswer;
          if (isCorrect) {
            correctAnswers++;
          }
        }
      }
    } else if (widget.answers is List<List>) {
      // 복잡한 터치 패턴 문제들 (알록달록, 음악과터치)
      List<List> complexAnswers = widget.answers as List<List>;

      for (int i = 0; i < complexAnswers.length; i++) {
        if (i < keys.length) {
          final userAnswer = complexAnswers[i];
          final correctAnswer = widget.data[keys[i]]["answer"];

          // 음악과터치 문제는 answer가 정수값이므로 다르게 처리
          if (widget.category == "음악과터치") {
            // 음악과터치는 userAnswer[0]이 실제 답변값
            bool isCorrect = userAnswer[0] == correctAnswer;
            if (isCorrect) {
              correctAnswers++;
            }
          } else {
            // 알록달록 문제는 터치 패턴 비교
            bool isCorrect = userAnswer.length == correctAnswer.length;
            if (isCorrect) {
              correctAnswers++;
            }
          }
        }
      }
    }

    // 기존 답변이 있는 경우 기존 점수 계산
    if (widget.originalAnswers != null) {
      if (widget.originalAnswers is List<int>) {
        List<int> originalSimpleAnswers = widget.originalAnswers as List<int>;

        for (int i = 0; i < originalSimpleAnswers.length; i++) {
          if (i < keys.length) {
            final userAnswer = originalSimpleAnswers[i];
            final correctAnswer = widget.data[keys[i]]["answer"];

            bool isCorrect = userAnswer == correctAnswer;
            if (isCorrect) {
              originalCorrectAnswers++;
            }
          }
        }
      } else if (widget.originalAnswers is List<List>) {
        List<List> originalComplexAnswers =
            widget.originalAnswers as List<List>;

        for (int i = 0; i < originalComplexAnswers.length; i++) {
          if (i < keys.length) {
            final userAnswer = originalComplexAnswers[i];
            final correctAnswer = widget.data[keys[i]]["answer"];

            if (widget.category == "음악과터치") {
              bool isCorrect = userAnswer[0] == correctAnswer;
              if (isCorrect) {
                originalCorrectAnswers++;
              }
            } else {
              bool isCorrect = userAnswer.length == correctAnswer.length;
              if (isCorrect) {
                originalCorrectAnswers++;
              }
            }
          }
        }
      }
    }

    // 0.0 ~ 1.0 범위의 비율로 계산 (LiquidCircleProgressWidget에서 *100 처리)
    correctPercentage =
        widget.data.length > 0 ? correctAnswers / widget.data.length : 0.0;
    originalCorrectPercentage =
        widget.data.length > 0
            ? originalCorrectAnswers / widget.data.length
            : 0.0;

    // 디버깅: 값 전달 경로 추적
    print('=== 값 전달 경로 추적 ===');
    print('correctAnswers: $correctAnswers');
    print('originalCorrectAnswers: $originalCorrectAnswers');
    print('widget.data.length: ${widget.data.length}');
    print(
      'correctPercentage 계산: $correctAnswers / ${widget.data.length} = $correctPercentage',
    );
    print(
      'originalCorrectPercentage 계산: $originalCorrectAnswers / ${widget.data.length} = $originalCorrectPercentage',
    );
    print('correctPercentage * 100: ${correctPercentage * 100}');
    print(
      '(correctPercentage * 100).toInt(): ${(correctPercentage * 100).toInt()}',
    );

    // 음악과터치 디버깅
    if (widget.category == "음악과터치") {
      print('=== 음악과터치 디버깅 ===');
      print('widget.answers: $widget.answers');
      print('widget.answers.runtimeType: ${widget.answers.runtimeType}');
      if (widget.answers is List<List>) {
        List<List> complexAnswers = widget.answers as List<List>;
        for (int i = 0; i < complexAnswers.length; i++) {
          print('answers[$i]: ${complexAnswers[i]}');
          print('answers[$i].runtimeType: ${complexAnswers[i].runtimeType}');
        }
      }
      print('=== 음악과터치 디버깅 완료 ===');
    }
    print('=== 추적 완료 ===');
  }

  void _retryWrongQuestion(int questionIndex) {
    // 틀린 문제로 돌아가기 (기존 답변도 함께 전달)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => BrainTrainingTestPage(
              title: widget.category,
              retryIndex: questionIndex,
              retryAnswers: widget.answers,
            ),
      ),
    );
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
      appBar: AppBar(
        backgroundColor: AppColors.btnColorDark,
        // automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
        toolbarHeight: _appBarH(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => BrainTrainingMainPage()),
              (route) => false,
            );
          },
        ),
        title: Center(
          child: Text(
            "테스트 결과",
            textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
            style: TextStyle(fontFamily: 'GmarketSans', fontWeight: FontWeight.w700, fontSize: 20.sp, color: Colors.white),
          ),
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  // LiquidCircleProgressWidget 복원
                  LiquidCircleProgressWidget(value: correctPercentage),

                  SizedBox(width: 20.w),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "레벤님의",
                        textScaler: const TextScaler.linear(
                          1.0,
                        ), // 시스템 폰트 크기 설정 무시
                        style: TextStyle(
                          color: AppColors.text,
                          fontFamily: 'GmarketSans',
                          fontWeight: FontWeight.w600,
                          fontSize: 20.sp,
                        ),
                      ),
                      Text(
                        "${widget.category} 영역 테스트 결과,\n${widget.data.length}개 중 $correctAnswers개를 맞혔어요! ",
                        textScaler: const TextScaler.linear(
                          1.0,
                        ), // 시스템 폰트 크기 설정 무시
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                        ),
                      ),
                      // 재풀이 모드인 경우 기존 점수와 비교 표시
                      if (widget.originalAnswers != null)
                        Text(
                          "기존: ${widget.data.length}개 중 $originalCorrectAnswers개 → 개선: ${widget.data.length}개 중 $correctAnswers개",
                          textScaler: const TextScaler.linear(
                            1.0,
                          ), // 시스템 폰트 크기 설정 무시
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Column(
                          children: List.generate(widget.data.keys.length, (
                            index,
                          ) {
                            final keys = widget.data.keys.toList();
                            final correctAnswer =
                                widget.data[keys[index]]["answer"];

                            // answers 타입에 따른 정답 판정
                            bool isCorrect = false;

                            if (widget.answers is List<int>) {
                              // 단순 선택형 문제들
                              List<int> simpleAnswers =
                                  widget.answers as List<int>;
                              if (index < simpleAnswers.length) {
                                final userAnswer = simpleAnswers[index];
                                isCorrect = userAnswer == correctAnswer;
                              }
                            } else if (widget.answers is List<List>) {
                              // 복잡한 터치 패턴 문제들
                              List<List> complexAnswers =
                                  widget.answers as List<List>;
                              if (index < complexAnswers.length) {
                                final userAnswer = complexAnswers[index];
                                // 음악과터치 문제는 answer가 정수값이므로 다르게 처리
                                if (widget.category == "음악과터치") {
                                  // 음악과터치는 userAnswer[0]이 실제 답변값
                                  isCorrect = userAnswer[0] == correctAnswer;
                                } else {
                                  // 알록달록 문제는 터치 패턴 비교
                                  isCorrect =
                                      userAnswer.length == correctAnswer.length;
                                }
                              }
                            }

                            return InkWell(
                              onTap: () {
                                // 틀린 문제인 경우에만 재시도 가능
                                if (!isCorrect) {
                                  _retryWrongQuestion(index);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      !isCorrect
                                          ? Colors.red.withOpacity(0.1)
                                          : null,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey,
                                      width: 1.w,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 5.h),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(width: 10.w),

                                            // 정답/오답 아이콘
                                            Icon(
                                              isCorrect
                                                  ? Icons.check_box_rounded
                                                  : Icons
                                                      .indeterminate_check_box_rounded,
                                              color:
                                                  isCorrect
                                                      ? AppColors.green
                                                      : AppColors.red,
                                              size: 24.h,
                                            ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              widget.data.keys.toList()[index],
                                              textScaler:
                                                  const TextScaler.linear(
                                                    1.0,
                                                  ), // 시스템 폰트 크기 설정 무시
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16.sp,
                                                color: AppColors.text,
                                                fontFamily: 'GmarketSans',
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          isCorrect
                                              ? Icons.navigate_next
                                              : Icons.navigate_next,
                                          size: 30.h,
                                          color:
                                              isCorrect
                                                  ? AppColors.text
                                                  : AppColors.red,
                                        ),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        SizedBox(width: 10.w),
                                        Flexible(
                                          child: Text(
                                            widget.data[widget.data.keys
                                                .toList()[index]]["title"],
                                            textScaler: const TextScaler.linear(
                                              1.0,
                                            ), // 시스템 폰트 크기 설정 무시
                                            style: TextStyle(fontSize: 13.sp),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                      ],
                                    ),

                                    SizedBox(height: 5.h),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),

                        SizedBox(height: 15.h),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30.h),

              // 홈으로
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    "홈으로",
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  ),
                ),
              ),

              SizedBox(height: 10.h),

              // 다시 풀기
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                BrainTrainingStartPage(title: widget.category),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.blue,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    "다시풀기",
                    textScaler: const TextScaler.linear(1.0), // 시스템 폰트 크기 설정 무시
                  ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
