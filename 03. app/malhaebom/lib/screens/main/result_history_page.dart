// lib/screens/main/result_history_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'package:malhaebom/theme/colors.dart';
import 'my_page.dart' show AttemptSummary; // byCategory 등 재사용
import 'package:malhaebom/screens/main/interview_result_page.dart' as ir;
import 'package:malhaebom/data/fairytale_assets.dart' as ft;

const String API_BASE = 'http://10.0.2.2:4000/str';
const TextScaler _fixedScale = TextScaler.linear(1.0);

// 빠른 실패(화면 전환 후 이 시간 경과 시 스피너 대신 오류 메시지 우선 표시)
const Duration kFastFailAfter = Duration(milliseconds: 700);
// HTTP 자체 타임아웃 (요청을 오래 끌지 않도록)
const Duration kHttpTimeout = Duration(seconds: 2);

enum HistoryMode { cognition, story }

class ResultHistoryPage extends StatefulWidget {
  const ResultHistoryPage({super.key, this.mode = HistoryMode.cognition});
  final HistoryMode mode;

  @override
  State<ResultHistoryPage> createState() => _ResultHistoryPageState();
}

class _ResultHistoryPageState extends State<ResultHistoryPage> {
  late Future<List<AttemptSummary>> _cogFuture;
  final Map<String, Future<List<StoryAttempt>>> _storyFutures = {};

  // fast-fail 표시용 플래그
  bool _showOfflineHint = false;
  Timer? _ffTimer;

  @override
  void initState() {
    super.initState();
    if (widget.mode == HistoryMode.cognition) {
      _cogFuture = _fetchCognitionList();
    }
    // 일정 시간 안에 응답이 없으면 오류 문구 먼저 보여주기
    _ffTimer = Timer(kFastFailAfter, () {
      if (mounted) setState(() => _showOfflineHint = true);
    });
  }

  @override
  void dispose() {
    _ffTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fixedMedia = MediaQuery.of(context).copyWith(textScaler: _fixedScale);

    return MediaQuery(
      data: fixedMedia,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.mode == HistoryMode.cognition ? '인지 검사 기록' : '동화 화행검사 결과',
          ),
          backgroundColor: AppColors.btnColorDark,
          centerTitle: true,
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          child: widget.mode == HistoryMode.cognition
              ? _buildCognitionBody()
              : _buildStoryBody(),
        ),
      ),
    );
  }

  // ---------------- cognition ----------------
  Widget _buildCognitionBody() {
    return FutureBuilder<List<AttemptSummary>>(
      future: _cogFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // fast-fail 시간 경과 시 즉시 오류 문구
          return _showOfflineHint
              ? const _HistoryMessage('기록을 불러올 수 없습니다.')
              : const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const _HistoryMessage('기록을 불러올 수 없습니다.');
        }
        final items = snap.data ?? const <AttemptSummary>[];
        if (items.isEmpty) {
          return const _HistoryMessage('저장된 검사 기록이 없습니다.');
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, i) {
            final a = items[i];
            final attemptNo = (items.length - i);
            final dateStr = _dateLabel(a.kstLabel, a.testedAt);
            final ratio = a.total == 0 ? 0.0 : a.score / a.total;

            return _Card(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                  childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                  iconColor: AppColors.text,
                  collapsedIconColor: AppColors.text,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateStr,
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
                        ),
                      ),
                      _AttemptChip('$attemptNo회차'),
                      SizedBox(width: 8.w),
                      Text(
                        '${a.score}점',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: _scoreColor(ratio),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    SizedBox(height: 6.h),
                    _scoreCircle(a.score, a.total),
                    SizedBox(height: 12.h),
                    _riskBarRow('반응 시간', a.byCategory['반응 시간']),
                    SizedBox(height: 10.h),
                    _riskBarRow('반복어 비율', a.byCategory['반복어 비율']),
                    SizedBox(height: 10.h),
                    _riskBarRow('평균 문장 길이', a.byCategory['평균 문장 길이']),
                    SizedBox(height: 10.h),
                    _riskBarRow('화행 적절성', a.byCategory['화행 적절성']),
                    SizedBox(height: 10.h),
                    _riskBarRow('회상어 점수', a.byCategory['회상어 점수']),
                    SizedBox(height: 10.h),
                    _riskBarRow('문법 완성도', a.byCategory['문법 완성도']),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- story ----------------
  Widget _buildStoryBody() {
    final titles = ft.Fairytales.map((e) => e.title).toList(growable: false);

    return ListView.separated(
      itemCount: titles.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, i) {
        final title = titles[i];

        return _Card(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              iconColor: AppColors.text,
              collapsedIconColor: AppColors.text,
              title: Text(title,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900)),
              onExpansionChanged: (expanded) {
                if (expanded && _storyFutures[title] == null) {
                  setState(() {
                    _storyFutures[title] = _fetchStoryList(title);
                  });
                }
              },
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 10.h),
                  child: FutureBuilder<List<StoryAttempt>>(
                    future: _storyFutures[title],
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return _showOfflineHint
                            ? const _HistoryMessage('기록을 불러올 수 없습니다.')
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator()),
                              );
                      }
                      if (snap.hasError) {
                        return const _HistoryMessage('기록을 불러올 수 없습니다.');
                      }
                      final attempts = snap.data ?? const <StoryAttempt>[];
                      if (attempts.isEmpty) {
                        return const _HistoryMessage('저장된 검사 기록이 없습니다.');
                      }

                      return Column(
                        children: List.generate(attempts.length, (idx) {
                          final a = attempts[idx];
                          final attemptNo = (attempts.length - idx);
                          final dateStr = _dateLabel(a.kstLabel, a.testedAt);
                          final ratio = a.total == 0 ? 0.0 : a.score / a.total;

                          return Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: _InnerCard(
                              child: Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.symmetric(
                                      horizontal: 12.w, vertical: 2.h),
                                  childrenPadding:
                                      EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
                                  iconColor: AppColors.text,
                                  collapsedIconColor: AppColors.text,
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      _AttemptChip('$attemptNo회차'),
                                      SizedBox(width: 8.w),
                                      Text(
                                        '${a.score}점',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w900,
                                          color: _scoreColor(ratio),
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    SizedBox(height: 6.h),
                                    _scoreCircle(a.score, a.total),
                                    SizedBox(height: 12.h),
                                    ...['요구', '질문', '단언', '의례화']
                                        .where((k) => a.byCategory.containsKey(k))
                                        .map((k) => Padding(
                                              padding:
                                                  EdgeInsets.only(bottom: 10.h),
                                              child: _riskBarRow(
                                                  k, a.byCategory[k]),
                                            )),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- networking ----------------
  Future<List<AttemptSummary>> _fetchCognitionList() async {
    final uri = Uri.parse('$API_BASE/attempt/list');
    final res = await http.get(uri).timeout(kHttpTimeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final arr = jsonDecode(res.body);
    if (arr is! List) return const <AttemptSummary>[];
    return arr
        .map((e) => AttemptSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StoryAttempt>> _fetchStoryList(String storyTitle) async {
    final uri = Uri.parse(
      '$API_BASE/story/attempt/list?title=${Uri.encodeQueryComponent(storyTitle)}',
    );
    final res = await http.get(uri).timeout(kHttpTimeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final arr = jsonDecode(res.body);
    if (arr is! List) return const <StoryAttempt>[];
    return arr
        .map((e) => StoryAttempt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------- UI utils ----------------
  Color _scoreColor(double ratio) {
    if (ratio >= 0.85) return const Color(0xFF10B981);
    if (ratio >= 0.6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _dateLabel(String? kstLabel, DateTime? testedAt) {
    if (kstLabel != null && kstLabel.trim().isNotEmpty) return kstLabel;
    if (testedAt != null) {
      final d = testedAt.toLocal();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd';
    }
    return '날짜 미상';
  }

  Widget _riskBarRow(String label, ir.CategoryStat? stat) {
    final ev = _evalFromStat(stat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                    color: const Color(0xFF4B5563),
                    fontFamily: 'GmarketSans',
                  ),
                ),
              ),
              _statusChip(ev),
            ],
          ),
        ),
        _riskBar(ev.position),
      ],
    );
  }

  Widget _riskBar(double position) => SizedBox(
        height: 16.h,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  width: w,
                  height: 6.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Positioned(
                  left: (w - 18.w) * position,
                  child: Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF9CA3AF), width: 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _statusChip(_EvalView ev) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: ev.badgeBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ev.badgeBorder),
        ),
        child: Text(
          ev.text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14.sp,
            color: ev.textColor,
            fontFamily: 'GmarketSans',
          ),
        ),
      );

  Widget _scoreCircle(int score, int total) {
    final double d = 120.w;
    final double big = d * 0.40;
    final double small = d * 0.20;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF4444), width: 8),
              color: Colors.white,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                textScaler: _fixedScale,
                style: TextStyle(
                  fontSize: big,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                  fontFamily: 'GmarketSans',
                ),
              ),
              Text(
                '/$total',
                textScaler: _fixedScale,
                style: TextStyle(
                  fontSize: small,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFEF4444),
                  height: 1.0,
                  fontFamily: 'GmarketSans',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _EvalView _evalFromStat(ir.CategoryStat? s) {
    if (s == null || s.total == 0) {
      return _EvalView(
        text: '데이터 없음',
        textColor: const Color(0xFF6B7280),
        badgeBg: const Color(0xFFF3F4F6),
        badgeBorder: const Color(0xFFE5E7EB),
        position: 0.5,
      );
    }
    final risk = s.riskRatio;
    if (risk > 0.75) {
      return _EvalView(
        text: '매우 주의',
        textColor: const Color(0xFFB91C1C),
        badgeBg: const Color(0xFFFFE4E6),
        badgeBorder: const Color(0xFFFCA5A5),
        position: risk,
      );
    } else if (risk > 0.5) {
      return _EvalView(
        text: '주의',
        textColor: const Color(0xFFDC2626),
        badgeBg: const Color(0xFFFFEBEE),
        badgeBorder: const Color(0xFFFECACA),
        position: risk,
      );
    } else if (risk > 0.25) {
      return _EvalView(
        text: '보통',
        textColor: const Color(0xFF92400E),
        badgeBg: const Color(0xFFFFF7ED),
        badgeBorder: const Color(0xFFFCD34D),
        position: risk,
      );
    } else {
      return _EvalView(
        text: '양호',
        textColor: const Color(0xFF065F46),
        badgeBg: const Color(0xFFECFDF5),
        badgeBorder: const Color(0xFF6EE7B7),
        position: risk,
      );
    }
  }
}

// ====== 동화용 모델 ======
class StoryAttempt {
  final String? storyTitle;
  final int score;
  final int total;
  final Map<String, ir.CategoryStat> byCategory;
  final Map<String, ir.CategoryStat> byType;
  final DateTime? testedAt;
  final String? kstLabel;

  StoryAttempt({
    required this.storyTitle,
    required this.score,
    required this.total,
    required this.byCategory,
    required this.byType,
    this.testedAt,
    this.kstLabel,
  });

  factory StoryAttempt.fromJson(Map<String, dynamic> j) {
    Map<String, ir.CategoryStat> _mapStats(dynamic x) {
      if (x is Map) {
        final out = <String, ir.CategoryStat>{};
        x.forEach((key, val) {
          if (val is Map) {
            final correct = (val['correct'] as num?)?.toInt() ?? 0;
            final total = (val['total'] as num?)?.toInt() ?? 0;
            out[key.toString()] = ir.CategoryStat(correct: correct, total: total);
          }
        });
        return out;
      }
      return <String, ir.CategoryStat>{};
    }

    DateTime? ts;
    final rawTs = j['attemptTime'] ?? j['testedAt'] ?? j['createdAt'];
    if (rawTs is String) ts = DateTime.tryParse(rawTs);

    return StoryAttempt(
      storyTitle: j['storyTitle'] as String?,
      score: (j['score'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      byCategory: _mapStats(j['byCategory']),
      byType: _mapStats(j['byType']),
      testedAt: ts,
      kstLabel: j['clientKst'] as String?,
    );
  }
}

// ====== 작은 위젯 ======
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _InnerCard extends StatelessWidget {
  const _InnerCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(12.r),
      child: child,
    );
  }
}

class _AttemptChip extends StatelessWidget {
  const _AttemptChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12.sp,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 24.h),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _EvalView {
  final String text;
  final Color textColor;
  final Color badgeBg;
  final Color badgeBorder;
  final double position;
  _EvalView({
    required this.text,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.position,
  });
}
