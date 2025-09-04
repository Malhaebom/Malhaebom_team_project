import os
import json
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from pydantic import BaseModel
import analyzer

# -------------------------------------------------------
# 인터뷰 JSON 로더
# -------------------------------------------------------
def _find_interview_json() -> Optional[Path]:
    # 1) 환경변수로 지정되면 최우선
    env_path = os.getenv("INTERVIEW_JSON_PATH")
    if env_path:
        p = Path(env_path).expanduser().resolve()
        if p.is_file():
            return p

    # 2) 후보 경로들: CWD, MAIN.py와 같은 폴더, 그 부모
    candidates = [
        Path.cwd() / "interview.json",
        Path(__file__).resolve().parent / "interview.json",
        Path(__file__).resolve().parent.parent / "interview.json",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None

def _load_interview_json(path: Path) -> List[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("interview.json must be a list of objects.")
    # 최소 필드 검증 및 정규화
    out: List[Dict[str, Any]] = []
    for i, item in enumerate(data, 1):
        if not isinstance(item, dict):
            raise ValueError(f"Item #{i} is not an object.")
        qid = item.get("question_id")
        title = item.get("title") or f"인터뷰하기{qid or i}"
        speech = item.get("speechText") or ""
        if not isinstance(qid, int) or qid <= 0:
            # question_id 누락 시 안전하게 i 사용
            qid = i
        out.append({"question_id": qid, "title": title, "speechText": speech})
    # question_id 기준으로 정렬(안전)
    out.sort(key=lambda x: x["question_id"])
    return out

def _index_by_id(items: List[Dict[str, Any]]) -> Dict[int, Dict[str, Any]]:
    return {int(it["question_id"]): it for it in items}

# -------------------------------------------------------
# FastAPI lifespan
# -------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("FastAPI 서버가 시작 준비에 들어갑니다.")

    # 0) 모델 예열
    analyzer.initialize_model()

    # 1) interview.json 로드
    try:
        json_path = _find_interview_json()
        if not json_path:
            raise FileNotFoundError("interview.json not found near server root.")
        items = _load_interview_json(json_path)
        app.state.interview_list = items
        app.state.interview_index = _index_by_id(items)
        app.state.interview_json_path = str(json_path)
        print(f"interview.json 로드 성공! 경로: {json_path}")
        if items:
            print(f"  -> 샘플(question_id={items[0]['question_id']}): {items[0]['speechText']}")
    except Exception as e:
        print(f"interview.json 로드 실패: {e}")
        app.state.interview_list = []
        app.state.interview_index = {}
        app.state.interview_json_path = None

    yield
    print("FastAPI 서버가 종료됩니다.")

app = FastAPI(lifespan=lifespan)

# -------------------------------------------------------
# 요청/응답 모델
# -------------------------------------------------------
class AnalysisRequest(BaseModel):
    # 둘 중 하나만 있어도 됨 (question_id가 있으면 JSON에서 질문 텍스트 조회)
    question_text: Optional[str] = None
    question_id: Optional[int] = None

    answer_text: str
    response_time: float = 0.0
    audio_duration: float = 0.0

class AnalysisResponse(BaseModel):
    final_score: int                 
    details: dict
    answer_text: str

# -------------------------------------------------------
# 내부 유틸
# -------------------------------------------------------
def _preview(text: str, max_len=120) -> str:
    if not text:
        return ""
    t = text.replace("\n", "\\n").replace("\r", "\\r")
    return t if len(t) <= max_len else f"{t[:max_len]}...(+{len(t)-max_len} chars)"

def _resolve_question_text(app: FastAPI, req: AnalysisRequest) -> str:
    # 우선 요청의 question_text 사용
    if req.question_text and req.question_text.strip():
        return req.question_text.strip()
    # 없으면 question_id로 app.state에서 조회
    if req.question_id and getattr(app.state, "interview_index", None):
        item = app.state.interview_index.get(int(req.question_id))
        if item and item.get("speechText"):
            return str(item["speechText"])
    # 최종 폴백
    return ""

# -------------------------------------------------------
# API 엔드포인트
# -------------------------------------------------------
@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_interview(request: AnalysisRequest):
    qtext = _resolve_question_text(app, request)
    print(f"분석 서버: 요청 수신(qid={request.question_id}, qlen={len(qtext)}, "
          f"ans='{_preview(request.answer_text)}')", flush=True)

    scores = analyzer.run_full_analysis(
        question=qtext,
        answer_text=request.answer_text,
        response_time=request.response_time,
        audio_duration=request.audio_duration,
    )
    final_score = int(sum(int(v) for v in scores.values()))   # ← 정수 합산
    print(f"분석 서버: 분석 완료 → 최종 점수 {final_score}/40", flush=True)

    return AnalysisResponse(
        final_score=final_score,
        details={k: int(v) for k, v in scores.items()},        # ← details도 int 보장
        answer_text=request.answer_text,
    )

@app.get("/questions")
async def get_interview_questions():
    """
    로드된 interview.json 전체를 반환합니다.
    """
    items = getattr(app.state, "interview_list", [])
    if items:
        return {"path": app.state.interview_json_path, "count": len(items), "questions": items}
    return {"error": "Interview questions not loaded or file not found."}

@app.get("/questions/{qid}")
async def get_question_by_id(qid: int):
    """
    단일 문항 조회 (question_id 기준).
    """
    idx = getattr(app.state, "interview_index", {})
    item = idx.get(int(qid))
    if item:
        return item
    return {"error": f"question_id {qid} not found"}
