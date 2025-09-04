# advanced_analyzer.py

import numpy as np
from collections import Counter
from konlpy.tag import Okt
from sentence_transformers import SentenceTransformer, util
import google.generativeai as genai

# --- 1. 모델 및 객체 초기화 ---
try:
    tokenizer = Okt()
    # 한국어 문장 임베딩에 특화된 경량 모델을 로드합니다.
    # 최초 실행 시 모델 파일을 다운로드하므로 시간이 걸릴 수 있습니다.
    embedding_model = SentenceTransformer('jhgan/ko-sroberta-multitask')
    print("고급 분석 모듈 준비 완료: 형태소 분석기 및 임베딩 모델 로드 성공")
except Exception as e:
    print(f"고급 분석 모듈 초기화 실패: {e}")
    tokenizer = None
    embedding_model = None

# --- LLM API 설정 (실제 키로 교체해야 합니다) ---
try:
    # genai.configure(api_key="YOUR_GOOGLE_API_KEY")
    # llm = genai.GenerativeModel('gemini-1.5-flash')
    # print("Gemini 모델 준비 완료")
    # 임시 Mock 모델 (API 키가 없을 때 테스트용)
    class MockLLM:
        def generate_content(self, prompt):
            class MockResponse:
                text = '{\n  "score": 85,\n  "reason": "질문의 핵심인 학창 시절 경험에 대해 구체적으로 답변하고 있습니다."\n}'
            return MockResponse()
    llm = MockLLM()
    print("⚠️ 경고: LLM API 키가 설정되지 않았습니다. Mock 모델을 사용합니다.")
except Exception as e:
    llm = None
    print(f"Gemini 모델 초기화 실패: {e}")



# --- 2. 고도화된 지표별 채점 함수 ---

def score_semantic_recall(question, answer):
    """1. 의미적 회상성 점수 (Semantic Recall)"""
    if not embedding_model or not answer.strip():
        return 0.0

    # 질문과 답변을 벡터로 변환 (임베딩)
    question_embedding = embedding_model.encode(question, convert_to_tensor=True)
    answer_embedding = embedding_model.encode(answer, convert_to_tensor=True)

    # 코사인 유사도 계산
    cosine_score = util.pytorch_cos_sim(question_embedding, answer_embedding)
    
    # 점수를 0~100 사이로 변환
    score = (cosine_score.item() + 1) / 2 * 100
    return max(0, min(100, score))

def score_contextual_appropriateness(question, answer):
    """2. 문맥적 적절성 점수 (LLM 기반)"""
    if not llm or not answer.strip():
        return 0.0

    prompt = f"""
    당신은 인지 능력 평가 전문가입니다. 주어진 질문과 답변을 분석하여, 답변이 질문의 의도에 얼마나 적절한지 평가해주세요.
    - 평가 기준:
      1. 질문의 핵심 내용과 직접적으로 관련이 있는가?
      2. 답변이 논리적으로 일관성이 있는가?
      3. 동문서답을 하거나 대화의 흐름을 벗어나지는 않았는가?
    - 위의 기준에 따라 0점에서 100점 사이의 점수를 매겨주세요.
    - 반드시 아래의 JSON 형식으로만 응답해주세요.

    {{
      "score": <점수 (정수)>,
      "reason": "<평가 이유 (한 문장)>"
    }}

    ---
    [질문]: "{question}"
    [답변]: "{answer}"
    ---
    """
    try:
        response = llm.generate_content(prompt)
        result = json.loads(response.text.strip())
        return float(result.get("score", 0))
    except Exception as e:
        print(f"LLM 평가 중 오류 발생: {e}")
        return 0.0

def score_fluency(text, audio_duration_seconds):
    """3. 유창성 점수 (발화 속도 및 필러 단어)"""
    if not tokenizer or not text.strip() or audio_duration_seconds == 0:
        return 0.0

    # 3-1. 필러(Filler) 단어 비율 계산
    words = text.split()
    filler_words = ['음', '어', '그', '저기', '이제', '막']
    filler_count = sum(1 for word in words if word in filler_words)
    filler_ratio = (filler_count / len(words)) * 100 if words else 0
    
    # 비율이 10% 이상이면 0점, 0%이면 100점
    filler_score = max(0.0, 100.0 - (filler_ratio * 10))

    # 3-2. 발화 속도 (초당 음절 수) 계산
    # (주의: 정확한 음절 계산은 복잡하므로, 여기서는 형태소 수를 근사치로 사용)
    morphs_count = len(tokenizer.morphs(text))
    sps = morphs_count / audio_duration_seconds # Syllables Per Second
    
    # 정상 발화 속도 범위를 3~7 음절/초로 가정
    if 3.0 <= sps <= 7.0:
        speed_score = 100.0
    elif 1.5 <= sps < 3.0 or 7.0 < sps <= 9.0:
        speed_score = 50.0
    else:
        speed_score = 0.0
        
    # 두 점수를 평균내어 최종 유창성 점수 산출
    return (filler_score + speed_score) / 2

# --- 3. 기존 분석 함수 (필요시 재사용) ---
# score_repetition_rate, score_grammar 등 기존 analyzer.py의 함수들을
# 여기에 그대로 가져와서 함께 사용할 수 있습니다.

# --- 4. 모든 분석을 통합하는 메인 함수 ---
def run_advanced_analysis(question, answer_text, response_time, audio_duration):
    """
    하나의 답변에 대해 모든 고급 분석을 실행하고 점수 딕셔너리를 반환합니다.
    """
    # 기존 분석 모듈의 함수들도 함께 호출
    # from analyzer import score_repetition_rate, score_grammar ...
    
    scores = {
        # 고도화된 지표
        "semantic_recall": score_semantic_recall(question, answer_text),
        "contextual_appropriateness": score_contextual_appropriateness(question, answer_text),
        "fluency": score_fluency(answer_text, audio_duration),
        
        # 기존 지표 (예시)
        # "repetition_rate": score_repetition_rate(answer_text),
        # "grammar_score": score_grammar(answer_text),
        "response_time": 100.0 - min(response_time * 10, 100.0)
    }
    
    return scores
