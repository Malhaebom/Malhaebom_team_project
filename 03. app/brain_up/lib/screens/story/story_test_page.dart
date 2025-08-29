// lib/screens/story/story_test_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:brain_up/data/fairytale_data.dart';
import 'package:brain_up/screens/story/story_test_result_page.dart';
import 'package:brain_up/theme/colors.dart';
import 'package:audioplayers/audioplayers.dart';

const String _kFont = 'GmarketSans';

// =========================
// 데이터 모델
// =========================
class StoryQuestion {
  final String category;
  final String prompt;
  final List<String> choices;
  final int? answerIndex;
  final String? cover;
  final List<String> sounds;

  const StoryQuestion({
    required this.category,
    required this.prompt,
    required this.choices,
    required this.answerIndex,
    this.cover,
    this.sounds = const [],
  });
}

// =========================
// 테스트 페이지
// =========================
class StoryTestPage extends StatefulWidget {
  final String title;
  final String storyImg;

  const StoryTestPage({super.key, required this.title, required this.storyImg});

  @override
  State<StoryTestPage> createState() => _StoryTestPageState();
}

class _StoryTestPageState extends State<StoryTestPage>
    with WidgetsBindingObserver {
  static const int _kPointsPerQuestion = 2;

  late final List<StoryQuestion> _questions;
  late final List<bool?> _answers;
  int _index = 0;
  int? _selected;
  int _pointScore = 0;
  late final int _validCount;

  // ====== 오디오 ======
  late final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _stateSub;
  int _soundCursor = 0;
  bool _isPlaying = false;
  bool _resumeAfterResume = true;

  // 이어재생을 위한 현재 트랙/위치
  String? _currentSrc;
  Duration _lastPos = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _questions = _loadQuestionsFromData(widget.title, widget.storyImg);
    _answers = List<bool?>.filled(_questions.length, null);
    _validCount = _questions.where((q) => q.answerIndex != null).length;

    _player = AudioPlayer();
    _player.setPlayerMode(PlayerMode.mediaPlayer);
    _player.setReleaseMode(ReleaseMode.stop);

    _stateSub = _player.onPlayerStateChanged.listen((s) {
      _isPlaying = s == PlayerState.playing;
    });

    _player.onPlayerComplete.listen((event) {
      if (!mounted) return;
      final tracks =
          _questions.isEmpty ? const <String>[] : _questions[_index].sounds;
      if (_soundCursor + 1 < tracks.length) {
        _soundCursor++;
        _playTrack(tracks[_soundCursor]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _preloadSounds();
      if (!mounted) return;
      _playCurrentQuestionSounds();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  // ====== 앱 라이프사이클: 백그라운드 시 일시정지, 복귀 시 이어듣기 ======
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // 재생 중이었는지 기록 + 현재 위치 저장
      _resumeAfterResume = _isPlaying || (_currentSrc != null);
      try {
        final pos = await _player.getCurrentPosition();
        if (pos != null) _lastPos = pos;
      } catch (_) {}
      await _player.pause(); // 백그라운드에서 소리 안 나게
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_resumeAfterResume && _currentSrc != null) {
        // resume() 대신 명시적 시퀀스로 확실하게 이어듣기
        try {
          await _player.stop(); // 세션 초기화
          await _player.setSource(_toSource(_currentSrc!));
          if (_lastPos > Duration.zero) {
            await _player.seek(_lastPos);
          }
          await _player.resume();
        } catch (_) {
          // 실패 시 fallback: play → (가능하면) seek
          try {
            await _player.play(_toSource(_currentSrc!));
            if (_lastPos > Duration.zero) {
              await _player.seek(_lastPos);
            }
          } catch (_) {}
        }
      }
    }
  }

  // ====== 사운드 프리로드 ======
  Future<void> _preloadSounds() async {
    final allSounds = <String>{};
    for (final q in _questions) {
      for (final soundPath in q.sounds) {
        if (!soundPath.startsWith('http')) {
          allSounds.add(soundPath);
        }
      }
    }
    if (allSounds.isEmpty) return;

    final keysToCache = allSounds.map(_toAssetKey).toList();
    try {
      await _player.audioCache.loadAll(keysToCache);
    } catch (_) {}
  }

  String _toAssetKey(String rawOrFull) {
    final r = rawOrFull.trim();
    return r.startsWith('assets/') ? r.substring('assets/'.length) : r;
  }

  // 현재 src 문자열을 AudioPlayers Source로 변환
  Source _toSource(String s) {
    final t = s.trim();
    if (t.startsWith('http')) return UrlSource(t);
    return AssetSource(_toAssetKey(t));
  }

  // 데이터 로드
  List<StoryQuestion> _loadQuestionsFromData(
    String title,
    String fallbackCover,
  ) {
    final root = FairytaleData().data[title];
    if (root == null) return const [];

    final cover = (root['image'] as String?) ?? fallbackCover;
    final List tests = (root['test'] as List?) ?? const [];

    return tests
        .map<StoryQuestion>((raw) {
          final type = (raw['type'] ?? '').toString();
          final prompt = (raw['title'] ?? '').toString();
          final choices =
              (raw['list'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
          final a = raw['answer'];

          List<String> sounds = const [];
          final rs = raw['sounds'];
          if (rs is List) {
            sounds = rs.map((e) => e.toString()).toList();
          } else if (raw['sound'] != null) {
            sounds = [raw['sound'].toString()];
          }

          int? ans;
          if (a is int) {
            if (a == 0) {
              ans = null;
            } else if (a > 0 && a <= choices.length) {
              ans = a - 1;
            } else {
              ans = null;
            }
          }

          return StoryQuestion(
            category: type,
            prompt: prompt,
            choices: choices,
            answerIndex: ans,
            cover: cover,
            sounds: sounds,
          );
        })
        .toList(growable: false);
  }

  // ====== 현재 문항 사운드 자동 재생 ======
  Future<void> _playCurrentQuestionSounds() async {
    await _player.stop();
    _soundCursor = 0;
    if (_questions.isEmpty) return;
    final tracks = _questions[_index].sounds;
    if (tracks.isEmpty) return;
    await _playTrack(tracks[_soundCursor]);
  }

  Future<void> _playTrack(String src) async {
    _currentSrc = src;
    _lastPos = Duration.zero;
    try {
      await _player.play(_toSource(src), position: Duration.zero);
    } catch (_) {}
  }

  void _onSelect(int idx) {
    setState(() => _selected = idx);
  }

  void _next() async {
    final q = _questions[_index];
    if (q.answerIndex != null && _selected != null) {
      final ok = (_selected == q.answerIndex);
      _answers[_index] = ok;
      if (ok) _pointScore += _kPointsPerQuestion;
    } else {
      _answers[_index] = null;
    }

    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
      _playCurrentQuestionSounds();
      return;
    }

    await _player.stop();

    final byCategory = <String, CategoryStat>{};
    final byType = <String, CategoryStat>{};

    CategoryStat _add(Map<String, CategoryStat> m, String key, bool correct) {
      final cur = m[key];
      final next = CategoryStat(
        correct: (cur?.correct ?? 0) + (correct ? 1 : 0),
        total: (cur?.total ?? 0) + 1,
      );
      m[key] = next;
      return next;
    }

    String _baseCat(String raw) {
      if (raw.contains('요구')) return '요구';
      if (raw.contains('질문')) return '질문';
      if (raw.contains('단언')) return '단언';
      if (raw.contains('의례화')) return '의례화';
      return '기타';
    }

    String? _typeCat(String raw) {
      if (raw.contains('직접')) return '직접화행';
      if (raw.contains('간접')) return '간접화행';
      if (raw.contains('질문')) return '질문화행';
      if (raw.contains('단언')) return '단언화행';
      if (raw.contains('의례화')) return '의례화화행';
      return null;
    }

    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.answerIndex == null) continue;
      final ok = _answers[i] ?? false;
      _add(byCategory, _baseCat(q.category), ok);
      final t = _typeCat(q.category);
      if (t != null) _add(byType, t, ok);
    }

    final int totalPoints = _validCount * _kPointsPerQuestion;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => StoryResultPage(
              score: _pointScore,
              total: totalPoints,
              byCategory: byCategory,
              byType: byType,
              testedAt: DateTime.now(),
              storyTitle: widget.title,
            ),
      ),
    );
  }

  double get _progress =>
      _questions.isEmpty ? 0 : (_index / _questions.length).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    // 기종에 맞는 상단바 크기 설정
    double _appBarH(BuildContext context) {
      final shortest = MediaQuery.sizeOf(context).shortestSide;
      if (shortest >= 840) return 88; // 큰 태블릿
      if (shortest >= 600) return 72; // 일반 태블릿
      return kToolbarHeight; // 폰(기본 56)
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.btnColorDark,
          centerTitle: true,
          toolbarHeight: _appBarH(context),
          title: Text(
            widget.title,
            style: TextStyle(
              fontFamily: _kFont,
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: Text(
            '해당 제목의 테스트가 없어요.',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // =================================
  // Widget Build Helpers
  // =================================

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.btnColorDark,
      elevation: 0,
      centerTitle: true,
      title: Text(
        '화행 인지검사',
        style: TextStyle(
          fontFamily: _kFont,
          fontWeight: FontWeight.w700,
          fontSize: 20.sp,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final q = _questions[_index];
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 10.h),
                  _buildQuestionHeader(q),
                  SizedBox(height: 10.h),
                  _buildQuestionPrompt(q),
                  SizedBox(height: 12.h),
                  _buildChoices(q),
                  SizedBox(height: 8.h),
                  _buildProgressBar(),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD43B),
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          onPressed: (_selected == null) ? null : _next,
          child: Text(
            _index < _questions.length - 1 ? '다음' : '완료',
            style: TextStyle(
              fontFamily: _kFont,
              fontWeight: FontWeight.w900,
              fontSize: 16.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionHeader(StoryQuestion q) {
    return Text(
      '${_index + 1}번. ${q.category}',
      textAlign: TextAlign.center,
      textScaler: const TextScaler.linear(1.0),
      style: TextStyle(
        fontFamily: _kFont,
        fontWeight: FontWeight.w800,
        fontSize: 24.sp,
        color: AppColors.btnColorDark,
      ),
    );
  }

  Widget _buildQuestionPrompt(StoryQuestion q) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        q.prompt,
        textAlign: TextAlign.center,
        textScaler: const TextScaler.linear(1.0),
        style: TextStyle(
          fontFamily: _kFont,
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF111827),
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildChoices(StoryQuestion q) {
    return Column(
      children: [
        for (int i = 0; i < q.choices.length; i++) ...[
          _choiceTile(
            index: i,
            text: q.choices[i],
            isSelected: _selected == i,
            onTap: () => _onSelect(i),
          ),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }

  // 진행바: 좌/우 숫자 텍스트
  Widget _buildProgressBar() {
    return Row(
      children: [
        Text(
          '${_index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.sp,
            color: AppColors.btnColorDark,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10.h,
              child: LayoutBuilder(
                builder:
                    (context, c) => Stack(
                      children: [
                        Container(
                          width: c.maxWidth,
                          color: const Color(0xFFE5E7EB),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: c.maxWidth * _progress,
                          color: AppColors.btnColorDark,
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          '${_questions.length}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.sp,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ===== UI helpers =====
  Widget _choiceTile({
    required int index,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final Color border =
        isSelected ? const Color(0xFF94A3B8) : const Color(0xFFE5E7EB);
    final Color bg = isSelected ? const Color(0xFFF8FAFC) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: border, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            _choiceNumber(index + 1, const Color(0xFF111827)),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                text,
                textScaler: const TextScaler.linear(1.0),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20.sp,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 보기 번호 원형 배지: 수직 정렬 문제 해결 + 스케일 고정
  Widget _choiceNumber(int n, Color color) {
    final d = 28.w;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$n',
        maxLines: 1,
        overflow: TextOverflow.visible,
        textScaler: const TextScaler.linear(1.0),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        strutStyle: StrutStyle(
          forceStrutHeight: true,
          height: 1.0,
          fontSize: (d * 0.48),
        ),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: (d * 0.48),
          height: 1.0,
          color: color,
        ),
      ),
    );
  }
}
