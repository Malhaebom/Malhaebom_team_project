// lib/screens/main/result_history_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'package:malhaebom/theme/colors.dart';

// AttemptSummary 모델은 MyPage에서 정의된 걸 재사용
import 'my_page.dart' show AttemptSummary;

// 상세 페이지와 타입은 여기도 ir 별칭으로 사용
import 'package:malhaebom/screens/main/interview_result_page.dart'
    as ir; // ← 경로 확인

const String API_BASE = 'http://10.0.2.2:4000/str';

class ResultHistoryPage extends StatefulWidget {
  const ResultHistoryPage({super.key});
  @override
  State<ResultHistoryPage> createState() => _ResultHistoryPageState();
}

class _ResultHistoryPageState extends State<ResultHistoryPage> {
  late Future<List<AttemptSummary>> _listFuture;

  @override
  void initState() {
    super.initState();
    _listFuture = _fetchList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('검사 기록'),
        backgroundColor: AppColors.btnColorDark,
        centerTitle: true,
      ),
      body: FutureBuilder<List<AttemptSummary>>(
        future: _listFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text('기록을 불러올 수 없습니다.'));
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('저장된 검사 기록이 없습니다.'));
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, i) {
              final a = items[i];
              final date = a.kstLabel ??
                  (a.testedAt != null
                      ? a.testedAt!.toLocal().toString()
                      : '날짜 미상');
              final ratio = a.total == 0 ? 0 : (a.score / a.total);
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                child: ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  title: Text(date,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16.sp)),
                  subtitle: Text(
                    '점수: ${a.score} / ${a.total}   (${(ratio * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ir.InterviewResultPage(
                          score: a.score,
                          total: a.total,
                          byCategory: a.byCategory,
                          byType: a.byType ?? <String, ir.CategoryStat>{},
                          testedAt: a.testedAt ?? DateTime.now(),
                          interviewTitle: a.interviewTitle,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<AttemptSummary>> _fetchList() async {
    try {
      final uri = Uri.parse('$API_BASE/attempt/list');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final arr = jsonDecode(res.body);
        if (arr is List) {
          return arr
              .map((e) => AttemptSummary.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
