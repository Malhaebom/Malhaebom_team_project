// lib/data/fairytale_repo.dart
import 'dart:collection';
import 'package:flutter/foundation.dart';

// 프로젝트 실제 경로에 맞게 수정하세요.
import 'fairytale_data.dart';

/// 한 줄 대사의 텍스트/오디오 정보를 담는 간단한 모델
class RoleLine {
  final String text;
  final String? sound; // null 가능 (일부엔 소스가 없을 수 있어서)
  RoleLine({required this.text, this.sound});
}

class FairytaleRepo {
  // ---- 제목 정규화 & 별칭 ----

  /// 사용자 입력/표시용 제목을 저장소 키와 비교 가능하도록 정규화
  static String _norm(String s) {
    // 1) 공백류 제거(일반/전각/제로폭) & 구두점(언더스코어/하이픈/슬래시/점) 제거
    const zws = [
      '\u200B', '\u200C', '\u200D', '\uFEFF', // zero width
    ];
    final buf = StringBuffer();
    for (final ch in s.trim().toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      if (zws.contains(c)) continue;
      if (c == ' ' || c == '\u3000') continue; // half/full width space
      if ('_-/.,'.contains(c)) continue;
      buf.write(c);
    }
    return buf.toString();
  }

  /// 제목 별칭(동일 작품의 다양한 표기)을 등록
  /// 키: 표준 제목, 값: 가능한 다른 표기들
  static final Map<String, List<String>> _aliases = {
    '아들의 호빵': ['아들의호빵', '아 들 의 호 빵', '아들의-호빵'],
    '할머니의 바나나': ['할머니의바나나', '할머니 의 바나나', '할머니의-바나나'],
    // 필요 시 여기에 계속 추가
  };

  /// 데이터 로딩 시 생성되는 정규화 인덱스(정규화된제목 -> 실제키)
  static Map<String, String>? _normIndex;

  static Map<String, String> _buildIndex(Map<String, dynamic> root) {
    final Map<String, String> out = {};
    for (final rawKey in root.keys) {
      final k = rawKey.toString();
      out[_norm(k)] = k;
      // 별칭도 역으로 매핑
      final alias = _aliases[k];
      if (alias != null) {
        for (final a in alias) {
          out[_norm(a)] = k;
        }
      }
    }
    // 별칭이 원본문이 없는 경우도 대비(별칭만 아는 경우)
    for (final entry in _aliases.entries) {
      final canonical = entry.key;
      final normCanon = _norm(canonical);
      for (final a in entry.value) {
        out.putIfAbsent(_norm(a), () => canonical);
      }
      // 원본 키 자체가 데이터에 없는 경우라도 일단 인덱스는 만들어 둠
      out.putIfAbsent(normCanon, () => canonical);
    }
    return out;
  }

  /// 어떤 표기로 들어와도 최선의 제목 키를 찾아줌
  static String? _resolveTitleKey(String anyTitle, Map<String, dynamic> root) {
    _normIndex ??= _buildIndex(root);

    final norm = _norm(anyTitle);
    // 1) 정규화 일치
    final hit = _normIndex![norm];
    if (hit != null && root.containsKey(hit)) return hit;

    // 2) 원문 그대로 일치 시도(데이터가 소문자/대문자 섞인 경우 대비)
    if (root.containsKey(anyTitle)) return anyTitle;

    // 3) 별칭 결과가 실제 데이터에 없으면 실패 처리
    return null;
  }

  // ---- 공개 API ----

  /// 동화 제목으로 rolePlay의 "텍스트 목록"만 반환
  static List<String> getRolePlayLines(String title) {
    final items = getRolePlayItems(title);
    return items.map((e) => e.text).toList(growable: false);
  }

  /// 동화 제목으로 rolePlay의 "텍스트/사운드"를 함께 반환 (정렬된 순서)
  static List<RoleLine> getRolePlayItems(String title) {
    try {
      final store = FairytaleData();
      final root = store.data;

      // 제목 해결(정규화/별칭 포함)
      final key = _resolveTitleKey(title, root);
      if (key == null) {
        if (kDebugMode) {
          debugPrint(
            '[FairytaleRepo] title not found: "$title" '
            '(norm="${_norm(title)}")',
          );
        }
        return const <RoleLine>[];
      }

      final dynamic story = root[key];
      if (story is! Map<String, dynamic>) return const <RoleLine>[];

      final dynamic rolePlay = story['rolePlay'];
      if (rolePlay == null) return const <RoleLine>[];

      // Map 형태: {"동화연극하기01": {"text": "...", "sound": "..."}, ...}
      if (rolePlay is Map) {
        final keys = rolePlay.keys.map((e) => e.toString()).toList();

        int order(String k) {
          final reg = RegExp(r'(\d+)$');
          final m = reg.firstMatch(k);
          if (m == null) return 1 << 30;
          return int.tryParse(m.group(1)!) ?? (1 << 30);
        }

        keys.sort((a, b) => order(a).compareTo(order(b)));

        final List<RoleLine> out = [];
        for (final k in keys) {
          final entry = rolePlay[k];
          if (entry is Map) {
            final t = (entry['text'] as String?)?.trim() ?? '';
            final s = (entry['sound'] as String?)?.trim();
            if (t.isNotEmpty) {
              out.add(
                RoleLine(text: t, sound: (s?.isNotEmpty == true) ? s : null),
              );
            }
          }
        }
        return out;
      }

      // List 형태: [{"text": "...", "sound": "..."}] 또는 ["문자열", ...]
      if (rolePlay is List) {
        final List<RoleLine> out = [];
        for (final e in rolePlay) {
          if (e is Map) {
            final t = (e['text'] as String?)?.trim() ?? '';
            final s = (e['sound'] as String?)?.trim();
            if (t.isNotEmpty) {
              out.add(
                RoleLine(text: t, sound: (s?.isNotEmpty == true) ? s : null),
              );
            }
          } else if (e is String && e.trim().isNotEmpty) {
            out.add(RoleLine(text: e.trim(), sound: null));
          }
        }
        return out;
      }

      return const <RoleLine>[];
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FairytaleRepo] error: $e\n$st');
      }
      return const <RoleLine>[];
    }
  }
}
