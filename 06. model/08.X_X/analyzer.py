# analyzer.py
from collections import Counter
import re
import kss
import unicodedata
from konlpy.tag import Okt
from sentence_transformers import SentenceTransformer, util
from custom_spell_checker import check_spelling

# ===============================
# 0) 전역 준비
# ===============================
tokenizer = None
embedding_model = None
try:
    tokenizer = Okt()
    embedding_model = SentenceTransformer('jhgan/ko-sroberta-multitask')
    print("분석 모듈 준비 완료: 형태소 분석기 및 임베딩 모델 로드 성공")
except Exception as e:
    print(f"분석 모듈 초기화 실패: {e}")

def initialize_model():
    if embedding_model:
        print("AI 모델 예열을 시작합니다...")
        embedding_model.encode("모델 예열 중", convert_to_tensor=True)
        print("AI 모델 예열 완료!")
    else:
        print("⚠️ AI 모델이 로드되지 않아 예열을 건너뜁니다.")

# ★ NEW: 무응답/유효성 최소 기준
MIN_VALID_AUDIO = 1.0   # 1초 미만 오디오는 무응답으로 간주
MIN_VALID_WORDS = 1     # 최소 1개 단어
MIN_VALID_CHARS = 2     # 최소 2글자


# ===============================
# 1) 공통 스코어러 (임계 조정)
# ===============================
def score_response_time(response_time_seconds: float,
                        *, audio_duration: float | None = None,
                        word_count: int = 0, char_count: int = 0) -> int:
    """반응 시간 (더 엄격):
       - 무응답(단어/글자 부족) 또는 오디오 너무 짧음(<1.0s) → 0점
       - <2s: 4점 / 2~4s: 2점 / >4s: 0점
    """
    if (word_count < MIN_VALID_WORDS or char_count < MIN_VALID_CHARS) \
       or (audio_duration is not None and audio_duration < MIN_VALID_AUDIO):
        return 0
    if response_time_seconds < 2:
        return 4
    elif response_time_seconds <= 4:
        return 2
    else:
        return 0


def score_repetition(text: str) -> int:
    """
    반복어 비율:
      ≤5%: 4점 / ≤10%: 2점 / ≥20%: 0점 / 그 사이: 1점
      ※ 내용어가 없으면 산정 불가 → 0점
    """
    if not tokenizer:
        return 0
    content_morphs = [w for w, tag in tokenizer.pos(text or "") if tag in ['Noun', 'Verb', 'Adjective']]
    if not content_morphs:
        return 0
    word_counts = Counter(content_morphs)
    repetition_count = sum(c - 1 for c in word_counts.values() if c > 1)
    ratio = (repetition_count / len(content_morphs)) * 100
    if ratio <= 5:
        return 4
    elif ratio <= 10:
        return 2
    elif ratio >= 20:
        return 0
    else:
        return 1


def _split_sentences(text: str):
    try:
        return kss.split_sentences(text)
    except Exception:
        return [s for s in text.replace('?', '.').replace('!', '.').split('.') if s.strip()]


def score_avg_sentence_length(text: str) -> int:
    """
    평균 문장 길이(어절 수):
      10–20: 4점 / 7–9, 21–25: 2점 / 그 외: 0점
    """
    sents = _split_sentences(text)
    if not sents:
        return 0
    total_tokens = 0
    for s in sents:
        total_tokens += max(1, len(s.strip().split()))  # 어절 근사
    avg_len = total_tokens / len(sents)
    if 10 <= avg_len <= 20:
        return 4
    elif (7 <= avg_len < 10) or (20 < avg_len <= 25):
        return 2
    else:
        return 0


def score_appropriateness_and_recall(question: str, answer_text: str):
    """
    화행 적절성(12) + 회상성(8) — 임베딩 유사도 기반:
      sim ≥ 0.72 -> 12/8
      0.55 ≤ sim < 0.72 -> 6/4
      else -> 0/0
    """
    if not embedding_model or not question.strip() or not answer_text.strip():
        return 0, 0
    e1 = embedding_model.encode(question, convert_to_tensor=True)
    e2 = embedding_model.encode(answer_text, convert_to_tensor=True)
    cos = util.pytorch_cos_sim(e1, e2).item()
    sim = (cos + 1) / 2  # 0~1
    if sim >= 0.72:
        return 12, 8
    elif sim >= 0.55:
        return 6, 4
    else:
        return 0, 0


def score_grammar(text: str) -> int:
    """문법 완성도 (8/4/0). ★ 빈 문자열은 0점."""
    t = (text or "").strip()
    if not t:
        return 0  # ★ CHANGED (기존: 8)
    err = check_spelling(t)
    L = len(t)
    per100 = (err / L) * 100 if L > 0 else 0
    if L < 20:
        if per100 == 0:
            return 4
        elif per100 <= 10:
            return 2
        else:
            return 0
    else:
        if per100 == 0:
            return 8
        elif per100 <= 10:
            return 4
        else:
            return 0


# ===============================
# 2) 질문 유형/키워드 매핑 & 유틸
# ===============================
def _normalize_q(s: str) -> str:
    """질문 텍스트를 키로 쓰기 위한 정규화(공백/구두점 제거, 줄바꿈 제거)."""
    if not s:
        return ""
    t = unicodedata.normalize("NFKC", s)
    t = re.sub(r'[\s\n\r\t]+', '', t)
    t = re.sub(r'[.,!?~:;\'"()\[\]{}<>·/\\\-]+', '', t)
    return t

# 전용 규칙이 필요한 문항만 명시 (그 외는 자동 추론)
QUESTION_RULES = {
    _normalize_q("오늘은 무슨 요일이고,\n지금 계신 곳은 어디인가요?"): {
        "type": "weekday_location"  # 요일 + 장소(지남력)
    },
    _normalize_q("오늘 아침 날씨가\n어땠는지 기억하시나요?"): {
        "type": "weather"
    },
    _normalize_q("제가 말씀드리는 세 가지 단어를 듣고 다시 말씀해 주시겠어요?\n사과, 시계, 책"): {
        "type": "enumeration",
        "expected_keywords": ["사과", "시계", "책"]
    },
}

ENUM_HINT_WORDS   = ['말하', '말해', '말하세요', '열거', '나열', '따라', '다시말', '다시 말']
RECALL_HINT_WORDS = ['기억', '추억', '언제', '누가', '어디서', '사건', '경험', '옛날', '최근']

WEEKDAYS = {'월','화','수','목','금','토','일','월요일','화요일','수요일','목요일','금요일','토요일','일요일','오늘'}
PLACE_SUFFIX = {'역','공원','시장','병원','학교','서점','도서관','사','사원','사찰','교회','성당','동','구','로','길','타워','해수욕장'}
PLACE_WORDS  = {'집','회사','병원','학교','마트','카페','식당','해운대','광안리','남포동','서면','부산','서울','부산역','남포역'}
WEATHER_TERMS = {'맑', '흐', '비', '눈', '바람', '덥', '춥', '쌀쌀', '후텁', '습', '선선', '따뜻', '따스', '소나기', '태풍'}

def detect_question_type(question: str) -> str:
    key = _normalize_q(question)
    if key in QUESTION_RULES:
        return QUESTION_RULES[key]['type']
    q = question or ""
    if any(h in q for h in ENUM_HINT_WORDS) and (',' in q or '·' in q or '와' in q or '과' in q or '그리고' in q):
        return 'enumeration'
    if any(h in q for h in RECALL_HINT_WORDS):
        return 'recall'
    return 'open'

def extract_expected_keywords(question: str):
    # 명시된 expected_keywords가 있으면 우선 사용
    key = _normalize_q(question)
    rule = QUESTION_RULES.get(key)
    if rule and 'expected_keywords' in rule:
        return rule['expected_keywords']

    parts = re.split(r'[,\u00B7·/]| 그리고 | 및 | 와 | 과 ', question or "")
    cands = []
    if tokenizer:
        for p in parts:
            nouns = [w for w, tag in tokenizer.pos(p) if tag in ['Noun', 'ProperNoun']]
            cands.extend(nouns)
    else:
        for p in parts:
            cands.extend(re.findall(r'[가-힣A-Za-z0-9]+', p))
    stop = {'를','을','은','는','이','가','와','과','및','그리고','말해','말하','말하세요','열거','나열','따라','읽어'}
    return [w for w in cands if w not in stop and len(w) >= 1][:10]

def coverage_of_keywords(answer_text: str, keywords: list[str]) -> float:
    if not keywords:
        return 0.0
    a = (answer_text or "").replace(' ', '')
    hit = sum(1 for kw in keywords if kw and kw in a)
    return hit / max(1, len(keywords))

def has_weekday(text: str) -> bool:
    t = text or ""
    return any(w in t for w in WEEKDAYS)

def has_place(text: str) -> bool:
    t = (text or "").replace(' ', '')
    if any(w in t for w in PLACE_WORDS):
        return True
    return any(t.endswith(sfx) or sfx in t for sfx in PLACE_SUFFIX)

def weather_hits(text: str) -> int:
    t = text or ""
    return sum(1 for w in WEATHER_TERMS if w in t)


# ===============================
# 3) 유형별 전용 스코어러
# ===============================
def score_enumeration(question: str, answer_text: str):
    """
    열거형(예: 사과·시계·책)
      - 키워드 커버리지로 적절성/회상 득점
      - 반복어/문장길이 감점 없음(=4점 고정)
      - 문법은 일반 규칙(짧으면 최대 4)
    """
    kws = extract_expected_keywords(question)
    cov = coverage_of_keywords(answer_text, kws)  # 0~1

    if cov >= 0.8:
        appr, rec = 12, 8
    elif cov >= 0.5:
        appr, rec = 10, 6
    elif cov > 0.0:
        appr, rec = 6, 4
    else:
        appr, rec = 0, 0

    rep = 4
    asl = 4
    gram = score_grammar(answer_text)

    return {
        "appropriateness": appr,
        "recall":          rec,
        "repetition":      rep,
        "avg_sentence_length": asl,
        "grammar":         gram,
    }

def score_weekday_location(answer_text: str):
    """
    요일 + 장소(지남력)
      - 둘 다 언급: 12/8
      - 하나만 언급: 8/4
    """
    wk = has_weekday(answer_text)
    pl = has_place(answer_text)

    if wk and pl:
        appr, rec = 12, 8
    elif wk or pl:
        appr, rec = 8, 4
    else:
        appr, rec = 0, 0

    rep = 4
    asl = 4
    gram = score_grammar(answer_text)

    return {
        "appropriateness": appr,
        "recall":          rec,
        "repetition":      rep,
        "avg_sentence_length": asl,
        "grammar":         gram,
    }

def score_weather(answer_text: str):
    """
    날씨 설명
      - 날씨 관련 키워드 2개 이상: 12/8
      - 1개: 8/6
    """
    hits = weather_hits(answer_text)
    if hits >= 2:
        appr, rec = 12, 8
    elif hits == 1:
        appr, rec = 8, 6
    else:
        appr, rec = 0, 0

    rep = 4
    asl = 4
    gram = score_grammar(answer_text)

    return {
        "appropriateness": appr,
        "recall":          rec,
        "repetition":      rep,
        "avg_sentence_length": asl,
        "grammar":         gram,
    }


# ===============================
# 4) 무의미/환각 필터
# ===============================
BLACKLIST_PATTERNS = [
    r"MBC\s*뉴스", r"KBS\s*뉴스", r"SBS\s*뉴스", r"YTN\s*뉴스", r"연합뉴스", r"뉴스데스크",
]

def is_trivial_or_hallucinated(answer_text: str, *, allow_short=False) -> bool:
    if not answer_text:
        return True
    text = answer_text.strip()
    if not allow_short:
        if len(text) < 8:
            return True
        if len(text.split()) < 3:
            return True
    for pat in BLACKLIST_PATTERNS:
        if re.search(pat, text):
            return True
    if len(text) <= 50 and ("뉴스" in text and ("입니다" in text or "마칩니다" in text)):
        return True
    return False


# ===============================
# 5) 메인: 질문 유형별로 분기
# ===============================
def run_full_analysis(question, answer_text, response_time, audio_duration):
    txt = (answer_text or "").strip()
    # 단어 수(공백 기준)와 글자 수
    word_count = len([w for w in re.findall(r'\S+', txt)])
    char_count = len(txt)

    # 디버깅 로그
    try:
        print(f"[GATE] audio_duration={audio_duration:.2f}s, words={word_count}, chars={char_count}")
    except Exception:
        print(f"[GATE] audio_duration={audio_duration}, words={word_count}, chars={char_count}")

    # ★ NEW: 무응답/유효하지 않은 음성 → 전항목 0점 즉시 반환
    if word_count < MIN_VALID_WORDS or char_count < MIN_VALID_CHARS or (audio_duration or 0) < MIN_VALID_AUDIO:
        scores = {
            "response_time": 0,
            "repetition": 0,
            "avg_sentence_length": 0,
            "appropriateness": 0,
            "recall": 0,
            "grammar": 0,
        }
        print(f"[NULL] 분석 결과: {scores}"); print(f"총점: {sum(scores.values())}/40")
        return scores

    # --- 질문 유형 선판별 ---
    qtype = detect_question_type(question)

    # --- 열거형(사과·시계·책 등) 전용 스코어
    if qtype == 'enumeration':
        scores_enum = score_enumeration(question, txt)
        scores = {
            "response_time": score_response_time(
                response_time,
                audio_duration=audio_duration,
                word_count=word_count,
                char_count=char_count
            ),
            **scores_enum
        }
        kws = extract_expected_keywords(question)
        cov = coverage_of_keywords(txt, kws)
        print(f"[ENUM] kws={kws} cov={cov:.2f}")
        print(f"분석 결과: {scores}"); print(f"총점: {sum(scores.values())}/40")
        return scores

    # --- 요일+장소 / 날씨 전용 룰 ---
    if qtype == 'weekday_location':
        wl_scores = score_weekday_location(txt)
        scores = {
            "response_time": score_response_time(
                response_time,
                audio_duration=audio_duration,
                word_count=word_count,
                char_count=char_count
            ),
            **wl_scores
        }
        print(f"[WEEKDAY/LOC] 분석 결과: {scores}"); print(f"총점: {sum(scores.values())}/40")
        return scores

    if qtype == 'weather':
        w_scores = score_weather(txt)
        scores = {
            "response_time": score_response_time(
                response_time,
                audio_duration=audio_duration,
                word_count=word_count,
                char_count=char_count
            ),
            **w_scores
        }
        print(f"[WEATHER] 분석 결과: {scores}"); print(f"총점: {sum(scores.values())}/40")
        return scores

    # --- 리콜형 질문은 '시간/인물 단서'가 있으면 후하게 ---
    if qtype == 'recall':
        TIME_HINTS   = ['지난', '작년', '올해', '이번', '어제', '주말', '월', '년', '주', '날', '아침', '점심', '저녁']
        PERSON_HINTS = ['가족', '아버지','어머니','아들','딸','손주','친구','선생님']
        hits = sum(1 for w in TIME_HINTS   if w in txt) + \
               sum(1 for w in PERSON_HINTS if w in txt)
        if hits >= 2:
            appr, rec = 12, 8
        elif hits == 1:
            appr, rec = 8, 6
        else:
            appr, rec = score_appropriateness_and_recall(question, txt)

        scores = {
            "response_time":       score_response_time(
                response_time,
                audio_duration=audio_duration,
                word_count=word_count,
                char_count=char_count
            ),
            "repetition":          score_repetition(txt),
            "avg_sentence_length": score_avg_sentence_length(txt),
            "appropriateness":     appr,
            "recall":              rec,
            "grammar":             score_grammar(txt),
        }
        print(f"[RECALL] hits={hits} -> 분석 결과: {scores}"); print(f"총점: {sum(scores.values())}/40")
        return scores

    # --- 일반(오픈형): 임베딩 + 필터
    trivial = is_trivial_or_hallucinated(txt, allow_short=True)  # 짧다고 바로 환각 취급 X
    if trivial:
        appr, rec = 0, 0
    else:
        appr, rec = score_appropriateness_and_recall(question, txt)

    scores = {
        "response_time":       score_response_time(
            response_time,
            audio_duration=audio_duration,
            word_count=word_count,
            char_count=char_count
        ),
        "repetition":          score_repetition(txt),
        "avg_sentence_length": score_avg_sentence_length(txt),
        "appropriateness":     appr,
        "recall":              rec,
        "grammar":             score_grammar(txt),
    }
    print(f"[{qtype.upper()}] 분석 결과: {scores}"); print(f"총점: {sum(scores.values())}/40")
    return scores
